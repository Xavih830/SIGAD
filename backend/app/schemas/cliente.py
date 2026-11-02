"""Pydantic schemas and Ecuadorian ID (Módulo 10) validator for Clientes and Vinculación."""

import re
import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator

from app.core.constants import MIN_PASSWORD_LENGTH, OTP_LENGTH
from app.schemas.base import StrictBaseSchema


def validar_cedula_ecuatoriana(cedula: str) -> bool:
    """Valida formalmente una cédula de identidad ecuatoriana mediante Módulo 10.

    Reglas:
    1. Limpiar espacios y verificar longitud exactamente de 10 dígitos numéricos.
    2. Código de provincia int(id[0:2]) en rango [1, 24] o igual a 30.
    3. Tercer dígito int(id[2]) en rango [0, 5] (persona natural).
    4. Coeficientes alternados: [2, 1, 2, 1, 2, 1, 2, 1, 2].
    5. Suma de productos con ajuste: si producto >= 10 -> (producto - 9).
    6. Comprobación de dígito verificador: (10 - (suma % 10)) % 10 == int(id[9]).
    """
    if not isinstance(cedula, str):
        return False

    clean_id = cedula.strip()
    if len(clean_id) != 10 or not clean_id.isdigit():
        return False

    provincia = int(clean_id[0:2])
    if (provincia < 1 or provincia > 24) and provincia != 30:
        return False

    tercer_digito = int(clean_id[2])
    if tercer_digito < 0 or tercer_digito > 5:
        return False

    coeficientes = [2, 1, 2, 1, 2, 1, 2, 1, 2]
    suma = 0
    for i in range(9):
        prod = int(clean_id[i]) * coeficientes[i]
        suma += (prod - 9) if prod >= 10 else prod

    digito_verificador = int(clean_id[9])
    calculado = (10 - (suma % 10)) % 10

    return digito_verificador == calculado


def validar_ruc_ecuatoriano(ruc: str) -> bool:
    """Valida formalmente un RUC ecuatoriano según el estándar del SRI.

    Tipos:
    1. Persona natural (tercer dígito 0 a 5):
       - 10 dígitos de cédula válida + establecimiento >= '001'.
    2. Sociedad pública (tercer dígito 6):
       - Coeficientes Módulo 11 (dígitos 1-8): [3, 2, 7, 6, 5, 4, 3, 2].
       - Verificador en dígito 9 (índice 8).
       - Establecimiento últimos 4 dígitos >= '0001'.
    3. Sociedad privada / extranjero (tercer dígito 9):
       - Coeficientes Módulo 11 (dígitos 1-9): [4, 3, 2, 7, 6, 5, 4, 3, 2].
       - Verificador en dígito 10 (índice 9).
       - Establecimiento últimos 3 dígitos >= '001'.
    """
    if not isinstance(ruc, str):
        return False

    clean_ruc = ruc.strip()
    if len(clean_ruc) != 13 or not clean_ruc.isdigit():
        return False

    provincia = int(clean_ruc[0:2])
    if (provincia < 1 or provincia > 24) and provincia != 30:
        return False

    tercer_digito = int(clean_ruc[2])

    if 0 <= tercer_digito <= 5:
        if not validar_cedula_ecuatoriana(clean_ruc[:10]):
            return False
        establecimiento = int(clean_ruc[10:13])
        return establecimiento >= 1

    if tercer_digito == 6:
        coeficientes = [3, 2, 7, 6, 5, 4, 3, 2]
        suma = sum(int(clean_ruc[i]) * coeficientes[i] for i in range(8))
        residuo = suma % 11
        calculado = 0 if residuo == 0 else (11 - residuo)
        if calculado == 10:
            return False
        if int(clean_ruc[8]) != calculado:
            return False
        establecimiento = int(clean_ruc[9:13])
        return establecimiento >= 1

    if tercer_digito == 9:
        coeficientes = [4, 3, 2, 7, 6, 5, 4, 3, 2]
        suma = sum(int(clean_ruc[i]) * coeficientes[i] for i in range(9))
        residuo = suma % 11
        calculado = 0 if residuo == 0 else (11 - residuo)
        if calculado == 10:
            return False
        if int(clean_ruc[9]) != calculado:
            return False
        establecimiento = int(clean_ruc[10:13])
        return establecimiento >= 1

    return False


def validar_identificacion(valor: str) -> bool:
    """Valida formalmente una identificación ecuatoriana (Cédula de 10 dígitos o RUC de 13 dígitos)."""
    if not isinstance(valor, str):
        return False
    clean = valor.strip()
    if len(clean) == 10:
        return validar_cedula_ecuatoriana(clean)
    if len(clean) == 13:
        return validar_ruc_ecuatoriano(clean)
    return False


def validar_complejidad_password(password: str) -> str:
    """Valida complejidad obligatoria de contraseña:

    - Mínimo MIN_PASSWORD_LENGTH caracteres.
    - Al menos 1 letra mayúscula.
    - Al menos 1 letra minúscula.
    - Al menos 1 número.
    - Al menos 1 carácter especial.
    """
    if len(password) < MIN_PASSWORD_LENGTH:
        raise ValueError(f"La contraseña debe tener al menos {MIN_PASSWORD_LENGTH} caracteres.")
    if not re.search(r"[A-Z]", password):
        raise ValueError("La contraseña debe incluir al menos una letra mayúscula.")
    if not re.search(r"[a-z]", password):
        raise ValueError("La contraseña debe incluir al menos una letra minúscula.")
    if not re.search(r"\d", password):
        raise ValueError("La contraseña debe incluir al menos un número.")
    if not re.search(r"[^a-zA-Z0-9\s]", password):
        raise ValueError("La contraseña debe incluir al menos un carácter especial.")
    return password


class ClienteCreate(StrictBaseSchema):
    """Schema para creación y onboarding de un cliente por un agente."""

    identificacion: str = Field(..., description="Cédula (10 dígitos) o RUC (13 dígitos) ecuatoriano")
    nombres: str = Field(..., min_length=2, max_length=255)
    email: EmailStr | None = None
    telefono: str | None = Field(None, max_length=20)

    @field_validator("identificacion")
    @classmethod
    def check_identificacion(cls, v: str) -> str:
        v_clean = v.strip()
        if not validar_identificacion(v_clean):
            raise ValueError("Identificación ecuatoriana inválida (Cédula de 10 dígitos o RUC de 13 dígitos).")
        return v_clean


class ClienteResponse(BaseModel):
    """Schema de respuesta para cliente registrado."""

    id: uuid.UUID
    identificacion: str
    nombres: str
    email: str | None = None
    telefono: str | None = None
    usuario_id: uuid.UUID | None = None
    created_at: datetime
    codigo_vinculacion: str | None = None

    model_config = ConfigDict(from_attributes=True)


class ClienteUpdate(StrictBaseSchema):
    """Schema para actualización parcial de datos de contacto de cliente."""

    nombres: str | None = Field(None, min_length=2, max_length=255)
    email: EmailStr | None = None
    telefono: str | None = Field(None, max_length=20)


class VinculacionRequest(StrictBaseSchema):
    """Payload para el flujo de vinculación móvil con OTP y contraseña."""

    cedula: str = Field(..., alias="identificacion")
    codigo_otp: str = Field(..., alias="codigo")
    password: str
    password_confirmacion: str | None = None
    email_opcional: str | None = Field(None, alias="email")

    model_config = ConfigDict(
        extra="forbid",
        strict=True,
        str_strip_whitespace=True,
        populate_by_name=True,
        from_attributes=True,
    )

    @field_validator("cedula")
    @classmethod
    def validate_cedula(cls, v: str) -> str:
        v_clean = v.strip()
        if not validar_cedula_ecuatoriana(v_clean):
            raise ValueError("Cédula de identidad ecuatoriana inválida (Módulo 10).")
        return v_clean

    @field_validator("codigo_otp")
    @classmethod
    def validate_otp_format(cls, v: str) -> str:
        v_clean = v.strip()
        if len(v_clean) != OTP_LENGTH or not v_clean.isdigit():
            raise ValueError(f"El código OTP debe contener exactamente {OTP_LENGTH} dígitos numéricos.")
        return v_clean

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        return validar_complejidad_password(v)

    @model_validator(mode="after")
    def validate_passwords_match(self) -> "VinculacionRequest":
        if self.password_confirmacion is not None and self.password != self.password_confirmacion:
            raise ValueError("La confirmación de la contraseña no coincide.")
        return self
