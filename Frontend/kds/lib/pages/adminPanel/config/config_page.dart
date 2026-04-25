import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config_provider.dart';
import 'widgets/empresa_tab.dart';
import 'widgets/sucursales_tab.dart';

class ConfigPage extends StatelessWidget {
  final ConfigProvider provider;

  const ConfigPage({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: const _ConfigView(),
    );
  }
}

class _ConfigView extends StatefulWidget {
  const _ConfigView();

  @override
  State<_ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<_ConfigView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con tabs
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Configuracion',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              const Text('Administra tu empresa y sucursales',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabCtrl,
                isScrollable: false,
                labelColor: const Color(0xFF6366F1),
                unselectedLabelColor: const Color(0xFF6B7280),
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 13),
                indicatorColor: const Color(0xFF6366F1),
                indicatorWeight: 2,
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Empresa'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.store_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Sucursales'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Contenido de tabs
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [
              EmpresaTab(),
              SucursalesTab(),
            ],
          ),
        ),
      ],
    );
  }
}