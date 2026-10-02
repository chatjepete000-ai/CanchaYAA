enum DataSourceMode { local, cloud }

abstract final class AppEnvironment {
  /// Durante la base universitaria la app puede trabajar con persistencia local.
  /// La capa de datos se mantendrá desacoplada para conectar Firebase sin
  /// reescribir las pantallas ni las reglas de negocio.
  static const DataSourceMode dataSourceMode = DataSourceMode.local;

  /// Cambiará a true cuando exista un proyecto Firebase configurado y validado.
  static const bool cloudReady = false;
}
