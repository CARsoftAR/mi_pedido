# pizzeria

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## REGLAS DE DESARROLLO Y COMPILACIÓN
1. **Compilación de APKs:** Siempre que se terminen cambios, se DEBEN compilar las APKs en la carpeta `C:\Apps\mi_pedido\RELEASES`.
2. **Nombres de Archivos:**
   - Admin: `MIGUEL_ANGEL_ADMIN.apk`
   - Cliente: `MIGUEL_ANGEL_CLIENTE.apk`
3. **Flavors:**
   - Admin: `flutter build apk --flavor admin -t lib/main_admin.dart`
   - Cliente: `flutter build apk --flavor cliente -t lib/main_client.dart`