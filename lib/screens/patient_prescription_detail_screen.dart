import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_api_service.dart';
import '../services/location_service.dart';
import '../services/prescriptions_api_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';

/// Detalle 1.5–1.6: ítems, pago simulado, dirección, GPS, mapa y seguimiento de envío.
class PatientPrescriptionDetailScreen extends StatefulWidget {
  final String prescriptionId;

  const PatientPrescriptionDetailScreen({super.key, required this.prescriptionId});

  @override
  State<PatientPrescriptionDetailScreen> createState() => _PatientPrescriptionDetailScreenState();
}

class _PatientPrescriptionDetailScreenState extends State<PatientPrescriptionDetailScreen> {
  final _api = PrescriptionsApiService();
  final _session = SessionService();
  final _location = LocationService();
  final _addrCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  PrescriptionDetailDto? _detail;
  bool _loading = true;
  String? _error;
  bool _actionBusy = false;

  /// Bogotá — referencia para vista de mapa si no hay coordenadas.
  static const double _defaultLat = 4.710989;
  static const double _defaultLng = -74.072092;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = await _session.getAccessToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Sesión no válida';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _api.getPatient(accessToken: token, id: widget.prescriptionId);
      if (!mounted) return;
      _addrCtrl.text = d.deliveryAddressLine ?? '';
      _cityCtrl.text = d.deliveryCity ?? '';
      setState(() {
        _detail = d;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _useMyGpsLocation() async {
    final token = await _session.getAccessToken();
    if (token == null || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      final p = await _location.getCurrentLatLng();
      if (!mounted) return;
      await _api.patchDelivery(
        accessToken: token,
        id: widget.prescriptionId,
        deliveryAddressLine: _addrCtrl.text.trim(),
        deliveryCity: _cityCtrl.text.trim(),
        deliveryLat: p.lat,
        deliveryLng: p.lng,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación GPS guardada en el mapa')),
      );
    } on LocationServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _pay() async {
    final token = await _session.getAccessToken();
    if (token == null || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      await _api.payPatient(accessToken: token, id: widget.prescriptionId);
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _saveAddress({double? lat, double? lng}) async {
    final token = await _session.getAccessToken();
    if (token == null || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      await _api.patchDelivery(
        accessToken: token,
        id: widget.prescriptionId,
        deliveryAddressLine: _addrCtrl.text.trim(),
        deliveryCity: _cityCtrl.text.trim(),
        deliveryLat: lat,
        deliveryLng: lng,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dirección guardada')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _ship() async {
    final token = await _session.getAccessToken();
    if (token == null || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      await _api.shipPatient(accessToken: token, id: widget.prescriptionId);
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _deliver() async {
    final token = await _session.getAccessToken();
    if (token == null || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      await _api.deliverPatient(accessToken: token, id: widget.prescriptionId);
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el mapa')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Fórmula',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.navy),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.red[800])),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    final d = _detail!;
    final lat = d.deliveryLat ?? _defaultLat;
    final lng = d.deliveryLng ?? _defaultLng;
    final mapUrl =
        'https://staticmap.openstreetmap.de/staticmap.php?center=$lat,$lng&zoom=15&size=600x200&markers=$lat,$lng,red-pushpin';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(d: d),
          const SizedBox(height: 12),
          Text(
            'Medicamentos',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy),
          ),
          const SizedBox(height: 8),
          ...d.items.map((it) => _ItemCard(it: it)),
          const SizedBox(height: 16),
          _TimelineCard(d: d),
          const SizedBox(height: 16),
          if (d.status == 'pending_payment') ...[
            FilledButton(
              onPressed: _actionBusy ? null : _pay,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _actionBusy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(
                      'Simular pago (COP ${_formatCop(d.estimatedTotalCents)})',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
          if (d.status == 'paid' || d.status == 'shipping' || d.status == 'delivered') ...[
            Text(
              'Entrega',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addrCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _cityCtrl,
              decoration: const InputDecoration(
                labelText: 'Ciudad',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _actionBusy ? null : _useMyGpsLocation,
              icon: const Icon(Icons.gps_fixed, size: 18),
              label: const Text('Usar mi ubicación actual (GPS)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _actionBusy
                  ? null
                  : () => _saveAddress(lat: _defaultLat, lng: _defaultLng),
              icon: const Icon(Icons.my_location_outlined, size: 18),
              label: const Text('Usar ubicación de referencia en mapa (Bogotá)'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _actionBusy ? null : () => _saveAddress(),
              child: Text('Guardar dirección', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
            if (d.status == 'paid') ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _actionBusy ? null : _ship,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Enviar pedido a domicilio',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
          if (d.status == 'shipping' || d.status == 'delivered') ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 600 / 200,
                child: Image.network(
                  mapUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: const Color(0xFFE5E7EB),
                    alignment: Alignment.center,
                    child: Text('Mapa no disponible', style: GoogleFonts.inter(color: AppColors.demoText)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openMap(lat, lng),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Abrir en Google Maps'),
            ),
          ],
          if (d.status == 'shipping') ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _actionBusy ? null : _deliver,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Marcar como entregado',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatCop(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _HeaderCard extends StatelessWidget {
  final PrescriptionDetailDto d;
  const _HeaderCard({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d.title,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy),
          ),
          if (d.specialistDisplayName != null && d.specialistDisplayName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                d.specialistDisplayName!,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.demoText),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final PrescriptionItemDto it;
  const _ItemCard({required this.it});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            it.drugName,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy),
          ),
          if (it.dosage != null && it.dosage!.isNotEmpty)
            Text('Dosis: ${it.dosage}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText)),
          if (it.posology != null && it.posology!.isNotEmpty)
            Text('Indicación: ${it.posology}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText)),
          if (it.quantity != null)
            Text('Cantidad: ${it.quantity}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.demoText)),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final PrescriptionDetailDto d;
  const _TimelineCard({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estado',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
          ),
          const SizedBox(height: 8),
          _Step(ok: true, label: 'Fórmula registrada', date: d.createdAt),
          _Step(ok: d.paidAt != null, label: 'Pago', date: d.paidAt),
          _Step(ok: d.shippedAt != null, label: 'En camino', date: d.shippedAt),
          _Step(ok: d.deliveredAt != null, label: 'Entregado', date: d.deliveredAt),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final bool ok;
  final String label;
  final String? date;

  const _Step({required this.ok, required this.label, this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: ok ? const Color(0xFF16A34A) : AppColors.hintGrey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ok ? AppColors.navy : AppColors.demoText,
              ),
            ),
          ),
          if (date != null && date!.isNotEmpty)
            Text(date!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.demoText)),
        ],
      ),
    );
  }
}
