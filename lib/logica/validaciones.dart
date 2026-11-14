/// Reglas de los formularios (login y registro), en un solo lugar para que
/// ambas pantallas pidan exactamente lo mismo.
/// Cada función devuelve null si está bien, o el mensaje de error si no.
library;

const int largoMinimoClave = 8;

final RegExp _formatoCorreo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validarCorreo(String correo) => _formatoCorreo.hasMatch(correo.trim())
    ? null
    : 'Revisa el correo. Debe verse así: nombre@correo.com';

String? validarClave(String clave) => clave.length >= largoMinimoClave
    ? null
    : 'La contraseña debe tener al menos $largoMinimoClave caracteres.';
