import 'package:flutter/material.dart';
import '../../../common/providers/auth_provider.dart';
import '../../../common/services/api_service.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class EmpresaRead {
  final String id;
  final String nombreLegal;
  final String nombreComercial;
  final String identificacion;
  final String tipoNegocio;
  final String email;
  final String? telefono;
  final String? direccionFiscal;
  final String pais;
  final String moneda;
  final String? logoUrl;
  final String timezone;
  final String estado;
  final Map<String, dynamic>? configuracion;

  const EmpresaRead({
    required this.id,
    required this.nombreLegal,
    required this.nombreComercial,
    required this.identificacion,
    required this.tipoNegocio,
    required this.email,
    this.telefono,
    this.direccionFiscal,
    required this.pais,
    required this.moneda,
    this.logoUrl,
    required this.timezone,
    required this.estado,
    this.configuracion,
  });

  factory EmpresaRead.fromJson(Map<String, dynamic> j) => EmpresaRead(
        id: j['id'] as String,
        nombreLegal: j['nombre_legal'] as String,
        nombreComercial: j['nombre_comercial'] as String,
        identificacion: j['identificacion'] as String,
        tipoNegocio: j['tipo_negocio'] as String,
        email: j['email'] as String,
        telefono: j['telefono'] as String?,
        direccionFiscal: j['direccion_fiscal'] as String?,
        pais: j['pais'] as String,
        moneda: j['moneda'] as String? ?? 'USD',
        logoUrl: j['logo_url'] as String?,
        timezone: j['timezone'] as String? ?? 'UTC',
        estado: j['estado'] as String,
        configuracion: j['configuracion'] as Map<String, dynamic>?,
      );
}

class SucursalRead {
  final String id;
  final String empresaId;
  final String codigo;
  final String nombre;
  final String tipo;
  final String? direccion;
  final String? ciudad;
  final String? estadoProvincia;
  final String? telefono;
  final String? email;
  final String estado;
  final String? horarioApertura;
  final String? horarioCierre;

  const SucursalRead({
    required this.id,
    required this.empresaId,
    required this.codigo,
    required this.nombre,
    required this.tipo,
    this.direccion,
    this.ciudad,
    this.estadoProvincia,
    this.telefono,
    this.email,
    required this.estado,
    this.horarioApertura,
    this.horarioCierre,
  });

  factory SucursalRead.fromJson(Map<String, dynamic> j) => SucursalRead(
        id: j['id'] as String,
        empresaId: j['empresa_id'] as String,
        codigo: j['codigo'] as String,
        nombre: j['nombre'] as String,
        tipo: j['tipo'] as String,
        direccion: j['direccion'] as String?,
        ciudad: j['ciudad'] as String?,
        estadoProvincia: j['estado_provincia'] as String?,
        telefono: j['telefono'] as String?,
        email: j['email'] as String?,
        estado: j['estado'] as String,
        horarioApertura: j['horario_apertura'] as String?,
        horarioCierre: j['horario_cierre'] as String?,
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class ConfigService {
  static Future<EmpresaRead> getEmpresa(String empresaId) async {
    final data = await ApiService.get('/api/v1/empresas/$empresaId');
    return EmpresaRead.fromJson(data as Map<String, dynamic>);
  }

  static Future<EmpresaRead> updateEmpresa(
      String empresaId, Map<String, dynamic> body) async {
    final data = await ApiService.patch('/api/v1/empresas/$empresaId', body);
    return EmpresaRead.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<SucursalRead>> getSucursales(String empresaId) async {
    final data = await ApiService.get(
        '/api/v1/sucursales/empresa/$empresaId?items_per_page=100');
    final items = (data['data'] as List? ?? []);
    return items
        .map((e) => SucursalRead.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<SucursalRead> createSucursal(
      Map<String, dynamic> body) async {
    final data = await ApiService.post('/api/v1/sucursales/', body);
    return SucursalRead.fromJson(data as Map<String, dynamic>);
  }

  static Future<SucursalRead> updateSucursal(
      String sucursalId, Map<String, dynamic> body) async {
    final data =
        await ApiService.patch('/api/v1/sucursales/$sucursalId', body);
    return SucursalRead.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteSucursal(String sucursalId) async =>
      await ApiService.delete('/api/v1/sucursales/$sucursalId');
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class ConfigProvider extends ChangeNotifier {
  EmpresaRead? empresa;
  List<SucursalRead> sucursales = [];
  bool isLoading = false;
  String? error;

  late String _empresaId;

  void init(AuthProvider auth) {
    _empresaId = auth.empresaId ?? '';
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        ConfigService.getEmpresa(_empresaId),
        ConfigService.getSucursales(_empresaId),
      ]);
      empresa = results[0] as EmpresaRead;
      sucursales = results[1] as List<SucursalRead>;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() async => await load();

  Future<bool> updateEmpresa(Map<String, dynamic> body) async {
    try {
      empresa = await ConfigService.updateEmpresa(_empresaId, body);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createSucursal(Map<String, dynamic> body) async {
    try {
      final nueva = await ConfigService.createSucursal(body);
      sucursales = [...sucursales, nueva];
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSucursal(
      String sucursalId, Map<String, dynamic> body) async {
    try {
      final updated =
          await ConfigService.updateSucursal(sucursalId, body);
      sucursales = sucursales
          .map((s) => s.id == sucursalId ? updated : s)
          .toList();
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSucursal(String sucursalId) async {
    try {
      await ConfigService.deleteSucursal(sucursalId);
      sucursales = sucursales.where((s) => s.id != sucursalId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }
}