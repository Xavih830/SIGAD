import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/constants/app_constants.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/repositories/clients_repository.dart';
import 'package:sigad/core/repositories/documents_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/file_picker_helper.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_form_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/ocr_document_detail_card.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/ocr_document_list_panel.dart';

class OcrTabView extends StatefulWidget {
  final DocumentsRepository? documentsRepository;
  final ClientsRepository? clientsRepository;

  const OcrTabView({
    super.key,
    this.documentsRepository,
    this.clientsRepository,
  });

  @override
  State<OcrTabView> createState() => _OcrTabViewState();
}

class _OcrTabViewState extends State<OcrTabView> {
  late final DocumentsRepository _docsRepo;
  late final ClientsRepository _clientsRepo;
  bool _isLoadingList = false, _isUploading = false, _isLoadingDetail = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _documentos = [];
  Map<String, dynamic>? _selectedDocument;

  @override
  void initState() {
    super.initState();
    _docsRepo = widget.documentsRepository ?? DocumentsRepository();
    _clientsRepo = widget.clientsRepository ?? ClientsRepository();
    _cargarDocumentos();
  }

  String? _getAuthToken() {
    final state = context.read<AuthBloc>().state;
    return state is AuthSuccess ? state.token : null;
  }

  Future<void> _cargarDocumentos() async {
    setState(() { _isLoadingList = true; _errorMessage = null; });
    try {
      final list = await _docsRepo.getDocuments(token: _getAuthToken());
      if (!mounted) return;
      setState(() {
        _documentos = list;
        _isLoadingList = false;
      });
      if (_documentos.isNotEmpty && _selectedDocument == null) {
        _seleccionarDocumento(_documentos.first['id'] as String);
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingList = false; _errorMessage = e.toString(); });
    }
  }

  Future<void> _seleccionarDocumento(String docId) async {
    setState(() => _isLoadingDetail = true);
    try {
      final doc = await _docsRepo.getDocumentById(docId, token: _getAuthToken());
      if (mounted) setState(() => _selectedDocument = doc);
    } finally {
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  Future<void> _abrirSelectorArchivo() async {
    final file = await FilePickerHelper.pickDocumentFile();
    if (file != null) _subirArchivo(file.bytes, file.name);
  }

  Future<void> _subirArchivo(Uint8List bytes, String filename) async {
    setState(() => _isUploading = true);
    try {
      final doc = await _docsRepo.uploadDocument(
        bytes: bytes,
        filename: filename,
        token: _getAuthToken(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo $filename subido.'), backgroundColor: AppTheme.successColor),
      );
      await _cargarDocumentos();
      await _seleccionarDocumento(doc['id'] as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _vincularNuevaPoliza(Map<String, dynamic> campos) async {
    List<ClientModel> clients = [];
    try {
      clients = await _clientsRepo.getClients(token: _getAuthToken());
    } catch (_) {}
    if (!mounted) return;

    // Parsear datos extraídos con tipado seguro — valores por defecto en AppConstants
    final double valorAsegurado = double.tryParse(campos['valor_asegurado']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? AppConstants.ocrDefaultInsuredValue;
    final double primaMensual = double.tryParse(campos['prima_mensual']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? AppConstants.ocrDefaultMonthlyPremium;
    final int kilometraje = int.tryParse(campos['kilometraje']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? AppConstants.ocrDefaultEmissionMileage;
    final String numeroPoliza = campos['numero_poliza']?.toString().isNotEmpty == true
        ? campos['numero_poliza']!.toString()
        : 'POL-OCR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    if (clients.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay clientes registrados. Cree un cliente antes de vincular una póliza OCR.'), backgroundColor: Colors.red));
      return;
    }
    final String clientId = clients.first.identificacion;


    final policy = PolicyModel(
      id: '',
      number: numeroPoliza,
      clientId: clientId,
      vehicleId: '',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 365)),
      status: 'activa',
      insuredValue: valorAsegurado,
      monthlyPremium: primaMensual,
      emissionMileage: kilometraje,
    );

    final created = await showDialog<PolicyModel>(
      context: context,
      builder: (_) => PolicyFormDialog(initialPolicy: policy, clients: clients),
    );

    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Póliza ${created.number} emitida con datos de OCR.'), backgroundColor: AppTheme.successColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && _documentos.isEmpty) return ErrorView(message: _errorMessage!, onRetry: _cargarDocumentos);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.borderLight)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: OcrDocumentListPanel(
                documentos: _documentos,
                selectedId: _selectedDocument?['id'] as String?,
                isLoading: _isLoadingList,
                isUploading: _isUploading,
                onRefresh: _cargarDocumentos,
                onUpload: _abrirSelectorArchivo,
                onSelect: _seleccionarDocumento,
              ),
            ),
            const VerticalDivider(width: 40, thickness: 1, color: AppTheme.borderLight),
            Expanded(
              flex: 3,
              child: OcrDocumentDetailCard(
                document: _selectedDocument,
                isLoading: _isLoadingDetail,
                onRefresh: () => _selectedDocument != null ? _seleccionarDocumento(_selectedDocument!['id'] as String) : null,
                onLinkPolicy: _vincularNuevaPoliza,
                authToken: _getAuthToken() ?? (throw StateError('OcrTabView renderizado con sesión nula. El BLoC de autenticación está en estado inválido.')),
                documentsRepository: _docsRepo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
