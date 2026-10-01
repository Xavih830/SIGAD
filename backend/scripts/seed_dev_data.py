#!/usr/bin/env python3
"""Database Seeder for Local Development & Testing.

Populates PostgreSQL with realistic, production-grade test data:
- Admin, Broker and Agent accounts with Argon2id passwords
- Clients with valid Ecuadorian Cédulas (Módulo 10 compliant)
- Linked client accounts for polymorphic mobile login
- Vehicles with standard ANT license plates
- Policies across all 5 domain lifecycle states (activa, por_vencer, vencida, cancelada, pendiente)
- Differentiated deductibles (SC-2026-001) and realistic coverage packages
- Nationwide authorized workshop catalog (Guayaquil, Quito, Cuenca, Samborondón)
- 24/7 Roadside assistance hotlines

Usage:
    python scripts/seed_dev_data.py           # Idempotent seed (upsert/insert missing)
    python scripts/seed_dev_data.py --clean   # Reset & purge old test data before seeding
"""

import argparse
import asyncio
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
import logging
import os
from pathlib import Path
import sys
import uuid

# Ensure backend root is on sys.path
backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from sqlalchemy import delete, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.db.session import async_session_factory
from app.domain.poliza_evaluator import EstadoPoliza
from app.models.asistencia import Asistencia
from app.models.cliente import Cliente
from app.models.codigo_vinculacion import CodigoVinculacion
from app.models.cobertura import Cobertura
from app.models.deducible import Deducible, TipoSiniestroEnum
from app.models.inspeccion import Inspeccion
from app.models.poliza import Poliza
from app.models.sesion_auth import SesionAuth
from app.models.taller import Taller
from app.models.usuario import RolEnum, Usuario
from app.models.vehiculo import Vehiculo

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("sigad.seeder")


DEV_DEFAULT_PASSWORD = "123456789"


async def clean_database(session: AsyncSession) -> None:
    """Truncate operational tables to guarantee a pristine, consistent local environment."""
    logger.info("Cleaning up accumulated test and mock data...")
    tables = [
        "sesiones_auth",
        "codigos_vinculacion",
        "coberturas",
        "deducibles",
        "polizas",
        "inspecciones",
        "vehiculos",
        "clientes",
        "talleres",
        "asistencias",
        "usuarios",
    ]
    # Fast atomic truncate with CASCADE
    truncate_query = f"TRUNCATE TABLE {', '.join(tables)} CASCADE;"
    await session.execute(text(truncate_query))
    await session.commit()
    logger.info("Database cleaned successfully.")


async def seed_data(session: AsyncSession, clean: bool = False) -> None:
    """Seed production-grade realistic data for local development and testing."""
    if clean:
        await clean_database(session)

    today = date.today()
    now_utc = datetime.now(timezone.utc)

    # ─────────────────────────────────────────────────────────────────────────
    # 1. USUARIOS (Roles: Admin, Broker RJ Seguros, Agente)
    # Contraseña unificada para testing local: 123456789
    # ─────────────────────────────────────────────────────────────────────────
    logger.info("Seeding system and broker users (password: %s)...", DEV_DEFAULT_PASSWORD)
    base_users = [
        {
            "email": "admin@sigad.ec",
            "nombre": "Administrador del Sistema",
            "password": DEV_DEFAULT_PASSWORD,
            "rol": RolEnum.ADMIN,
        },
        {
            "email": "ariana@rjseguros.ec",
            "nombre": "Ariana Guerrón",
            "password": DEV_DEFAULT_PASSWORD,
            "rol": RolEnum.ADMIN,
        },
        {
            "email": "agente@rjseguros.ec",
            "nombre": "Agente Autorizado RJ Seguros",
            "password": DEV_DEFAULT_PASSWORD,
            "rol": RolEnum.AGENTE,
        },
    ]

    for u_data in base_users:
        res = await session.execute(select(Usuario).where(Usuario.email == u_data["email"]))
        existing = res.scalar_one_or_none()
        if not existing:
            u = Usuario(
                email=u_data["email"],
                nombre=u_data["nombre"],
                password_hash=hash_password(u_data["password"]),
                rol=u_data["rol"],
                activo=True,
            )
            session.add(u)
            logger.info("  + Usuario creado: %s (%s)", u_data["email"], u_data["rol"].value)

    await session.flush()

    # ─────────────────────────────────────────────────────────────────────────
    # 2. CLIENTES CON CÉDULAS VÁLIDAS (Módulo 10) Y CUENTAS VINCULADAS
    # ─────────────────────────────────────────────────────────────────────────
    logger.info("Seeding clients, vehicles, and linked user credentials...")
    clients_seed = [
        {
            "identificacion": "0926687856",
            "nombres": "Carlos Eduardo Pérez Morales",
            "email": "c.perez@gmail.com",
            "telefono": "0987654321",
            "password": DEV_DEFAULT_PASSWORD,
            "vehiculos": [
                {
                    "placa": "GPA-1234",
                    "marca": "Toyota",
                    "modelo": "Corolla Cross XEI",
                    "anio": 2022,
                    "km_inspeccion": 34200,
                    "poliza": {
                        "numero": "POL-VL-2026-001",
                        "inicio": today - timedelta(days=120),
                        "fin": today + timedelta(days=245),
                        "estado": EstadoPoliza.ACTIVA,
                        "valor": Decimal("24500.00"),
                        "prima": Decimal("68.50"),
                        "km": 34200,
                        "coberturas": [
                            ("Daño Propio y Colisión Total/Parcial", Decimal("24500.00")),
                            ("Responsabilidad Civil Extracontractual", Decimal("35000.00")),
                            ("Accidentes Personales a Ocupantes", Decimal("15000.00")),
                            ("Asistencia en Carretera 24/7", Decimal("5000.00")),
                        ],
                        "deducibles": [
                            (TipoSiniestroEnum.GENERAL, Decimal("10.00"), Decimal("150.00")),
                            (TipoSiniestroEnum.ROBO, Decimal("15.00"), Decimal("250.00")),
                            (TipoSiniestroEnum.CHOQUE, Decimal("10.00"), Decimal("150.00")),
                            (TipoSiniestroEnum.PERDIDA_TOTAL, Decimal("10.00"), Decimal("500.00")),
                        ],
                    },
                },
                {
                    "placa": "PBA-9876",
                    "marca": "Nissan",
                    "modelo": "Versa Advance CVT",
                    "anio": 2024,
                    "km_inspeccion": 250,
                    "poliza": {
                        "numero": "POL-VL-2026-007",
                        "inicio": today + timedelta(days=10),
                        "fin": today + timedelta(days=375),
                        "estado": EstadoPoliza.PENDIENTE,
                        "valor": Decimal("21500.00"),
                        "prima": Decimal("62.00"),
                        "km": 250,
                        "coberturas": [
                            ("Daño Propio Flota Nueva", Decimal("21500.00")),
                            ("Responsabilidad Civil", Decimal("30000.00")),
                        ],
                        "deducibles": [
                            (TipoSiniestroEnum.GENERAL, Decimal("10.00"), Decimal("150.00")),
                            (TipoSiniestroEnum.ROBO, Decimal("15.00"), Decimal("250.00")),
                        ],
                    },
                },
            ],
        },
        {
            "identificacion": "1710034065",
            "nombres": "María José León Andrade",
            "email": "m.leon@hotmail.com",
            "telefono": "0976543210",
            "password": DEV_DEFAULT_PASSWORD,
            "vehiculos": [
                {
                    "placa": "PBX-5678",
                    "marca": "Chevrolet",
                    "modelo": "Sail 1.5 MT Sedan",
                    "anio": 2021,
                    "km_inspeccion": 48100,
                    "poliza": {
                        "numero": "POL-VL-2026-002",
                        "inicio": today - timedelta(days=350),
                        "fin": today + timedelta(days=15),  # 15 días restantes -> POR_VENCER
                        "estado": EstadoPoliza.POR_VENCER,
                        "valor": Decimal("13800.00"),
                        "prima": Decimal("42.00"),
                        "km": 48100,
                        "coberturas": [
                            ("Daños Propios", Decimal("13800.00")),
                            ("Responsabilidad Civil", Decimal("25000.00")),
                            ("Robo Total del Vehículo", Decimal("13800.00")),
                        ],
                        "deducibles": [
                            (TipoSiniestroEnum.GENERAL, Decimal("10.00"), Decimal("150.00")),
                            (TipoSiniestroEnum.ROBO, Decimal("15.00"), Decimal("200.00")),
                            (TipoSiniestroEnum.CHOQUE, Decimal("10.00"), Decimal("150.00")),
                            (TipoSiniestroEnum.PERDIDA_TOTAL, Decimal("10.00"), Decimal("400.00")),
                        ],
                    },
                }
            ],
        },
        {
            "identificacion": "0103456786",
            "nombres": "Roberto Antonio Vega Cruz",
            "email": "r.vega@gmail.com",
            "telefono": "0965432109",
            "password": DEV_DEFAULT_PASSWORD,
            "vehiculos": [
                {
                    "placa": "ABC-9012",
                    "marca": "Hino",
                    "modelo": "300 Serie 714 Cabina Simple",
                    "anio": 2020,
                    "km_inspeccion": 115000,
                    "poliza": {
                        "numero": "POL-VP-2026-003",
                        "inicio": today - timedelta(days=90),
                        "fin": today + timedelta(days=275),
                        "estado": EstadoPoliza.ACTIVA,
                        "valor": Decimal("45000.00"),
                        "prima": Decimal("195.00"),
                        "km": 115000,
                        "coberturas": [
                            ("Daño Propio Vehículo Pesado", Decimal("45000.00")),
                            ("Responsabilidad Civil Ampliada", Decimal("60000.00")),
                            ("Carga Transportada en Tránsito", Decimal("25000.00")),
                            ("Auxilio Mecánico en Ruta Nacional", Decimal("10000.00")),
                        ],
                        "deducibles": [
                            (TipoSiniestroEnum.GENERAL, Decimal("12.00"), Decimal("300.00")),
                            (TipoSiniestroEnum.ROBO, Decimal("20.00"), Decimal("500.00")),
                            (TipoSiniestroEnum.CHOQUE, Decimal("12.00"), Decimal("300.00")),
                            (TipoSiniestroEnum.PERDIDA_TOTAL, Decimal("15.00"), Decimal("800.00")),
                        ],
                    },
                }
            ],
        },
        {
            "identificacion": "1104567894",
            "nombres": "Elena Patricia Gómez Zambrano",
            "email": "e.gomez@yahoo.com",
            "telefono": "0991234567",
            "password": DEV_DEFAULT_PASSWORD,
            "vehiculos": [
                {
                    "placa": "PCY-4567",
                    "marca": "Hyundai",
                    "modelo": "Tucson 2.0 GL 4x2",
                    "anio": 2023,
                    "km_inspeccion": 18300,
                    "poliza": {
                        "numero": "POL-VL-2026-004",
                        "inicio": today - timedelta(days=340),
                        "fin": today + timedelta(days=25),  # 25 días restantes -> POR_VENCER
                        "estado": EstadoPoliza.POR_VENCER,
                        "valor": Decimal("28500.00"),
                        "prima": Decimal("84.00"),
                        "km": 18300,
                        "coberturas": [
                            ("Daño Propio", Decimal("28500.00")),
                            ("Responsabilidad Civil", Decimal("40000.00")),
                            ("Asistencia Vial Completa", Decimal("5000.00")),
                        ],
                        "deducibles": [
                            (TipoSiniestroEnum.GENERAL, Decimal("10.00"), Decimal("150.00")),
                            (TipoSiniestroEnum.ROBO, Decimal("15.00"), Decimal("250.00")),
                            (TipoSiniestroEnum.CHOQUE, Decimal("10.00"), Decimal("150.00")),
                            (TipoSiniestroEnum.PERDIDA_TOTAL, Decimal("10.00"), Decimal("500.00")),
                        ],
                    },
                }
            ],
        },
        {
            "identificacion": "1805678909",
            "nombres": "David Fernando Castro Ortiz",
            "email": "d.castro@outlook.com",
            "telefono": "0958765432",
            "password": DEV_DEFAULT_PASSWORD,
            "vehiculos": [
                {
                    "placa": "TBH-2345",
                    "marca": "Kia",
                    "modelo": "Sportage LX 2.0",
                    "anio": 2020,
                    "km_inspeccion": 62000,
                    "poliza": {
                        "numero": "POL-VL-2025-005",
                        "inicio": today - timedelta(days=400),
                        "fin": today - timedelta(days=35),  # Venció hace 35 días -> VENCIDA
                        "estado": EstadoPoliza.VENCIDA,
                        "valor": Decimal("19000.00"),
                        "prima": Decimal("58.00"),
                        "km": 62000,
                        "coberturas": [
                            ("Daño Propio Histórico", Decimal("19000.00")),
                            ("Responsabilidad Civil", Decimal("25000.00")),
                        ],
                        "deducibles": [
                            (TipoSiniestroEnum.GENERAL, Decimal("10.00"), Decimal("150.00")),
                            (TipoSiniestroEnum.ROBO, Decimal("15.00"), Decimal("200.00")),
                        ],
                    },
                },
                {
                    "placa": "GSX-7890",
                    "marca": "Suzuki",
                    "modelo": "Grand Vitara SZ 2.4",
                    "anio": 2019,
                    "km_inspeccion": 74500,
                    "poliza": {
                        "numero": "POL-VL-2026-006",
                        "inicio": today - timedelta(days=90),
                        "fin": today + timedelta(days=275),
                        "estado": EstadoPoliza.CANCELADA,
                        "valor": Decimal("16500.00"),
                        "prima": Decimal("49.00"),
                        "km": 74500,
                        "coberturas": [
                            ("Daño Propio", Decimal("16500.00")),
                        ],
                        "deducibles": [
                            (TipoSiniestroEnum.GENERAL, Decimal("10.00"), Decimal("150.00")),
                        ],
                    },
                },
            ],
        },
    ]

    for c_data in clients_seed:
        # Verificar o crear Usuario del cliente
        res_u = await session.execute(select(Usuario).where(Usuario.email == c_data["email"]))
        user = res_u.scalar_one_or_none()
        if not user:
            user = Usuario(
                email=c_data["email"],
                nombre=c_data["nombres"],
                password_hash=hash_password(c_data["password"]),
                rol=RolEnum.CLIENTE,
                activo=True,
            )
            session.add(user)
            await session.flush()
            logger.info("  + Usuario cliente creado: %s (Cédula: %s)", c_data["email"], c_data["identificacion"])

        # Verificar o crear Cliente
        res_c = await session.execute(select(Cliente).where(Cliente.identificacion == c_data["identificacion"]))
        cliente = res_c.scalar_one_or_none()
        if not cliente:
            cliente = Cliente(
                identificacion=c_data["identificacion"],
                nombres=c_data["nombres"],
                email=c_data["email"],
                telefono=c_data["telefono"],
                usuario_id=user.id,
            )
            session.add(cliente)
            await session.flush()
            logger.info("  + Cliente registrado: %s (%s)", c_data["nombres"], c_data["identificacion"])
        else:
            if cliente.usuario_id != user.id:
                cliente.usuario_id = user.id
                await session.flush()

        # Registrar Vehículos, Inspecciones, Pólizas, Coberturas y Deducibles
        for v_data in c_data["vehiculos"]:
            res_v = await session.execute(select(Vehiculo).where(Vehiculo.placa == v_data["placa"]))
            vehiculo = res_v.scalar_one_or_none()
            if not vehiculo:
                vehiculo = Vehiculo(
                    placa=v_data["placa"],
                    marca=v_data["marca"],
                    modelo=v_data["modelo"],
                    anio=v_data["anio"],
                    cliente_id=cliente.id,
                )
                session.add(vehiculo)
                await session.flush()
                logger.info("    + Vehículo registrado: %s %s %s [Placa: %s]", vehiculo.marca, vehiculo.modelo, vehiculo.anio, vehiculo.placa)

            # Inspección técnica con lectura de kilometraje
            res_insp = await session.execute(
                select(Inspeccion).where(Inspeccion.vehiculo_id == vehiculo.id).order_by(Inspeccion.fecha.desc()).limit(1)
            )
            inspeccion = res_insp.scalar_one_or_none()
            if not inspeccion:
                inspeccion = Inspeccion(
                    vehiculo_id=vehiculo.id,
                    kilometraje=v_data["km_inspeccion"],
                    observaciones=f"Inspección periódica inicial sin novedades mecánicas. Odómetro verificado en {v_data['km_inspeccion']} km.",
                )
                session.add(inspeccion)
                await session.flush()

            # Póliza
            p_info = v_data["poliza"]
            res_p = await session.execute(select(Poliza).where(Poliza.numero_poliza == p_info["numero"]))
            poliza = res_p.scalar_one_or_none()
            if not poliza:
                poliza = Poliza(
                    numero_poliza=p_info["numero"],
                    cliente_id=cliente.id,
                    vehiculo_id=vehiculo.id,
                    inspeccion_id=inspeccion.id,
                    fecha_inicio=p_info["inicio"],
                    fecha_fin=p_info["fin"],
                    estado=p_info["estado"],
                    valor_asegurado=p_info["valor"],
                    prima_mensual=p_info["prima"],
                    kilometraje_emision=p_info["km"],
                )
                session.add(poliza)
                await session.flush()
                logger.info("      + Póliza emitida: %s [%s] ($%s / mes)", poliza.numero_poliza, poliza.estado.value, poliza.prima_mensual)

                # Coberturas asociadas
                for cob_nom, cob_monto in p_info["coberturas"]:
                    cob = Cobertura(
                        poliza_id=poliza.id,
                        nombre=cob_nom,
                        monto=cob_monto,
                    )
                    session.add(cob)

                # Deducibles diferenciados (SC-2026-001)
                for t_sin, pct, min_usd in p_info["deducibles"]:
                    ded = Deducible(
                        poliza_id=poliza.id,
                        tipo_siniestro=t_sin,
                        porcentaje_valor=pct,
                        monto_minimo_usd=min_usd,
                    )
                    session.add(ded)

    await session.flush()

    # ─────────────────────────────────────────────────────────────────────────
    # 3. TALLERES AUTORIZADOS A NIVEL NACIONAL
    # ─────────────────────────────────────────────────────────────────────────
    logger.info("Seeding authorized workshops catalog...")
    talleres_seed = [
        {
            "nombre": "Taller Automotriz Espinoza",
            "direccion": "Av. Carlos Julio Arosemena Km 2.5",
            "ciudad": "Guayaquil",
            "telefono": "04-2234567",
            "activo": True,
        },
        {
            "nombre": "Centro Automotriz del Pacífico",
            "direccion": "Av. de las Américas 1250",
            "ciudad": "Guayaquil",
            "telefono": "04-2345678",
            "activo": True,
        },
        {
            "nombre": "Tecnicar Service Center",
            "direccion": "Vía a Samborondón Km 1.2",
            "ciudad": "Samborondón",
            "telefono": "04-2456789",
            "activo": True,
        },
        {
            "nombre": "AutoServicio Andino Quito",
            "direccion": "Av. 10 de Agosto N34-12 y Mariana de Jesús",
            "ciudad": "Quito",
            "telefono": "02-2456789",
            "activo": True,
        },
        {
            "nombre": "Mecánica Automotriz Tomebamba",
            "direccion": "Av. España y Huayna Cápac",
            "ciudad": "Cuenca",
            "telefono": "07-2865432",
            "activo": True,
        },
    ]

    for t_data in talleres_seed:
        res_t = await session.execute(select(Taller).where(Taller.nombre == t_data["nombre"]))
        if not res_t.scalar_one_or_none():
            taller = Taller(
                nombre=t_data["nombre"],
                direccion=t_data["direccion"],
                ciudad=t_data["ciudad"],
                telefono=t_data["telefono"],
                activo=t_data["activo"],
            )
            session.add(taller)
            logger.info("  + Taller creado: %s (%s)", t_data["nombre"], t_data["ciudad"])

    # ─────────────────────────────────────────────────────────────────────────
    # 4. ASISTENCIAS EN CARRETERA Y NÚMEROS DE EMERGENCIA 24/7
    # ─────────────────────────────────────────────────────────────────────────
    logger.info("Seeding roadside emergency assistance services...")
    asistencias_seed = [
        {
            "titulo": "Grúa y Remolque 24/7",
            "descripcion": "Servicio de plataforma y traslado de grúa a nivel nacional ante avería mecánica o siniestro vial.",
            "telefono_emergencia": "1800-742431",
            "icono": "local_shipping",
            "activo": True,
        },
        {
            "titulo": "Auxilio Mecánico In Situ",
            "descripcion": "Asistencia vial para cambio de neumático de repuesto, paso de corriente eléctrica y suministro de combustible.",
            "telefono_emergencia": "1800-742432",
            "icono": "build",
            "activo": True,
        },
        {
            "titulo": "Cerrajería Vial y Desbloqueo",
            "descripcion": "Desbloqueo técnico de puertas y cerraduras por olvido o pérdida de llaves en el interior del vehículo.",
            "telefono_emergencia": "1800-742433",
            "icono": "lock_open",
            "activo": True,
        },
        {
            "titulo": "Ambulancia y Emergencia Médica",
            "descripcion": "Coordinación y despacho de ambulancias de soporte vital avanzado ante accidentes de tránsito.",
            "telefono_emergencia": "1800-742434",
            "icono": "emergency",
            "activo": True,
        },
    ]

    for a_data in asistencias_seed:
        res_a = await session.execute(select(Asistencia).where(Asistencia.titulo == a_data["titulo"]))
        if not res_a.scalar_one_or_none():
            asistencia = Asistencia(
                titulo=a_data["titulo"],
                descripcion=a_data["descripcion"],
                telefono_emergencia=a_data["telefono_emergencia"],
                icono=a_data["icono"],
                activo=a_data["activo"],
            )
            session.add(asistencia)
            logger.info("  + Asistencia creada: %s (%s)", a_data["titulo"], a_data["telefono_emergencia"])

    await session.commit()
    logger.info("Seeding process completed successfully!")


async def main():
    parser = argparse.ArgumentParser(description="SIGAD PostgreSQL Dev/Test Data Seeder")
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Purge and reset all operational tables before seeding new data",
    )
    args = parser.parse_args()

    async with async_session_factory() as session:
        await seed_data(session, clean=args.clean)


if __name__ == "__main__":
    asyncio.run(main())
