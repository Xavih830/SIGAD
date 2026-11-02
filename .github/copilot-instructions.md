# Instrucciones del agente para SIGAD

## Contexto del proyecto

- SIGAD es una aplicación Flutter/Dart para la gestión y análisis documental de pólizas vehiculares de RJ Seguros.
- Las áreas principales están en `lib/features/auth`, `lib/features/mobile_client` y `lib/features/web_dashboard`.
- Los servicios, utilidades, tema y widgets compartidos están en `lib/core`.

## Forma de trabajo

- Antes de modificar código, inspecciona la implementación y los tests relacionados.
- Mantén los cambios pequeños y alineados con la arquitectura existente.
- Usa `flutter analyze` y los tests relevantes después de modificar Dart o Flutter.
- No cambies datos de ejemplo, dependencias ni archivos generados salvo que la tarea lo requiera.
- Conserva la compatibilidad entre web, Android e iOS cuando toques servicios de plataforma.
- No inventes APIs, requisitos del negocio o datos de pólizas. Si falta información, indícalo claramente.
- Responde en español, salvo que el usuario solicite otro idioma.

## Reglas para herramientas y agentes

- Lee primero los archivos relevantes y explica brevemente la hipótesis antes de editar.
- Ejecuta herramientas únicamente cuando sean necesarias para completar la tarea.
- Después de editar, valida el cambio con el comando más específico disponible.
- Si una herramienta falla, reporta el error real y no afirmes que la acción se completó.

## Nota para Ollama/Gemma

Este archivo solo se aplica automáticamente cuando el cliente o agente integra las instrucciones de workspace. Si Gemma se ejecuta mediante la API de Ollama, el programa debe leer este archivo y enviarlo en el mensaje `system`; además debe proporcionar `tools`, ejecutar las funciones solicitadas y devolver sus resultados al modelo en un bucle de agente.