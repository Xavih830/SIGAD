/// Función proveedora de tokens de autenticación para [ApiClient].
/// Permite desacoplar el cliente de red del mecanismo de almacenamiento concreto (SessionVault).
typedef TokenProvider = String? Function();
