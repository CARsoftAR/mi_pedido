# Informe de Trabajo - Proyecto Miguel Angel

## Tareas Completadas

### 1. Comandera (App Comercio)
- Se integró la librería `blue_thermal_printer` para permitir la impresión de tickets.
- Se implementó la lógica de generación de tickets con diseño profesional:
  - Información del cliente (Nombre, Dirección, WhatsApp).
  - Detalle de productos y cantidades.
  - Subtotal, Envío y Total.
  - Método de pago y vuelto (si corresponde).
- Se añadió un **botón de impresora** en cada tarjeta de pedido en `lib/orders_screen.dart` para ejecutar la impresión con un solo toque.

### 2. Sincronización de Disponibilidad (App Cliente)
- Se mejoró la comunicación entre las apps: si un producto es marcado como "No disponible" en la App Admin, se refleja inmediatamente en el Cliente.
- **Validación en el Carrito:** En `lib/cart_summary_screen.dart`, se añadieron dos capas de seguridad:
  1. **Limpieza Automática:** Al abrir el resumen de compra, si detecta ítems agotados, los elimina de la bolsa y avisa al usuario.
  2. **Verificación Pre-Envío:** Antes de confirmar el pedido y enviar el WhatsApp, se realiza una verificación final contra la base de datos para asegurar que no se vendan productos agotados en el último segundo.

### 3. Solución de Compilación y Permisos
- Se detectó un error de compatibilidad entre el plugin `blue_thermal_printer` y Android Gradle Plugin 8.0+. Se implementó un script de corrección automática en `android/build.gradle.kts` que limpia los manifiestos de los plugins al compilar.
- **Permisos de Bluetooth:** Se agregaron permisos específicos para Android 12+ (`BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`) para optimizar la conexión con la impresora y reducir el pedido de permisos genéricos de ubicación.
- **Nota:** En Android, es normal que el sistema pida permiso de ubicación al conectar dispositivos Bluetooth por primera vez. **Solo hay que aceptarlo una vez**.

### 4. Actualizaciones de Configuración
- Se actualizó el **Alias de Mercado Pago** predeterminado a `bonzalosc22.uala`.

## Estado de los Ejecutables (Compilación en curso)
- **App Cliente:** Generando versión con nuevo Alias.
- **App Comercio/Admin:** Generando versión con permisos de Bluetooth corregidos.
