import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../common/models/producto_models.dart';
import '../../../common/providers/auth_provider.dart';
import '../../../common/services/api_service.dart';
import 'menu_provider.dart';
import 'widgets/add_categoria_modal.dart';
import 'widgets/edit_categoria_modal.dart';
import 'widgets/add_producto_modal.dart';
import 'widgets/edit_producto_modal.dart';
import 'widgets/producto_sucursal_modal.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) {
        final auth = ctx.read<AuthProvider>();
        return MenuProvider()
          ..init(auth)
          ..load();
      },
      child: Consumer<MenuProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            backgroundColor: const Color(0xFFF9FAFB),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Menú',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${provider.categorias.length} categorías · '
                            '${provider.totalProductos} productos',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: provider.reload,
                            icon: const Icon(Icons.refresh_outlined,
                                color: Color(0xFF6B7280)),
                            tooltip: 'Actualizar',
                          ),
                          const SizedBox(width: 8),
                          // Botón contextual según pestaña activa
                          AnimatedBuilder(
                            animation: _tabController,
                            builder: (_, __) => _tabController.index == 0
                                ? _AddBtn(
                                    label: 'Nueva Categoría',
                                    onTap: () => _showAddCategoria(provider),
                                  )
                                : _AddBtn(
                                    label: 'Nuevo Producto',
                                    onTap: () => _showAddProducto(provider),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // TabBar
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF2563EB),
                    unselectedLabelColor: const Color(0xFF6B7280),
                    indicatorColor: const Color(0xFF2563EB),
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Categorías'),
                      Tab(text: 'Productos'),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),

                // Contenido
                Expanded(
                  child: provider.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF2563EB)))
                      : provider.error != null
                          ? _ErrorView(
                              message: provider.error!,
                              onRetry: provider.reload,
                            )
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _CategoriasTab(
                                  provider: provider,
                                  onEdit: (c) =>
                                      _showEditCategoria(c, provider),
                                  onDelete: (c) =>
                                      _confirmarDeleteCategoria(c, provider),
                                ),
                                _ProductosTab(
                                  provider: provider,
                                  onEdit: (p) =>
                                      _showEditProducto(p, provider),
                                  onDelete: (p) =>
                                      _confirmarDeleteProducto(p, provider),
                                  onConfigSucursal: (p) =>
                                      _showProductoSucursal(p, provider),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddCategoria(MenuProvider provider) {
    if (provider.empresaId == null) return;
    showDialog(
      context: context,
      builder: (_) => AddCategoriaModal(
        empresaId: provider.empresaId!,
        onSuccess: provider.reload,
      ),
    );
  }

  void _showEditCategoria(CategoriaRead cat, MenuProvider provider) {
    showDialog(
      context: context,
      builder: (_) => EditCategoriaModal(
        categoria: cat,
        onSuccess: provider.reload,
      ),
    );
  }

  Future<void> _confirmarDeleteCategoria(
      CategoriaRead cat, MenuProvider provider) async {
    final confirmed = await _showConfirmDialog(
      title: 'Desactivar categoría',
      content:
          '¿Desactivar "${cat.nombre}"? Los productos de esta categoría no se verán afectados.',
    );
    if (confirmed == true) {
      try {
        await MenuService.deleteCategoria(cat.id);
        provider.reload();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _showAddProducto(MenuProvider provider) {
    if (provider.empresaId == null) return;
    showDialog(
      context: context,
      builder: (_) => AddProductoModal(
        empresaId: provider.empresaId!,
        categorias: provider.categorias,
        onSuccess: provider.reload,
      ),
    );
  }

  void _showEditProducto(ProductoRead producto, MenuProvider provider) {
    showDialog(
      context: context,
      builder: (_) => EditProductoModal(
        producto: producto,
        categorias: provider.categorias,
        onSuccess: provider.reload,
      ),
    );
  }

  void _showProductoSucursal(ProductoRead producto, MenuProvider provider) {
    if (provider.sucursalId == null) return;
    showDialog(
      context: context,
      builder: (_) => ProductoSucursalModal(
        producto: producto,
        sucursalId: provider.sucursalId!,
        onSuccess: provider.reload,
      ),
    );
  }

  Future<void> _confirmarDeleteProducto(
      ProductoRead producto, MenuProvider provider) async {
    final confirmed = await _showConfirmDialog(
      title: 'Desactivar producto',
      content:
          '¿Desactivar "${producto.nombre}"? Se deshabilitará en todas las sucursales.',
      destructive: true,
    );
    if (confirmed == true) {
      try {
        await MenuService.deleteProducto(producto.id);
        provider.reload();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(content,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF6B7280))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(destructive ? 'Desactivar' : 'Confirmar',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Tab de Categorías ─────────────────────────────────────────────────────────
class _CategoriasTab extends StatelessWidget {
  final MenuProvider provider;
  final void Function(CategoriaRead) onEdit;
  final void Function(CategoriaRead) onDelete;

  static const _labelsTipo = {
    'alimento': 'Alimento',
    'bebida': 'Bebida',
    'producto': 'Producto',
    'servicio': 'Servicio',
  };

  static const _colorsTipo = {
    'alimento': (Color(0xFFD97706), Color(0xFFFFFBEB)),
    'bebida': (Color(0xFF2563EB), Color(0xFFEFF6FF)),
    'producto': (Color(0xFF7C3AED), Color(0xFFF5F3FF)),
    'servicio': (Color(0xFF16A34A), Color(0xFFF0FDF4)),
  };

  const _CategoriasTab({
    required this.provider,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.categorias.isEmpty) {
      return const _EmptyView(
        icon: Icons.category_outlined,
        message: 'No hay categorías',
        sublabel: 'Crea una categoría para organizar tu menú',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: provider.categorias
            .map((cat) => _CategoriaCard(
                  categoria: cat,
                  labelsTipo: _labelsTipo,
                  colorsTipo: _colorsTipo,
                  onEdit: () => onEdit(cat),
                  onDelete: () => onDelete(cat),
                ))
            .toList(),
      ),
    );
  }
}

class _CategoriaCard extends StatelessWidget {
  final CategoriaRead categoria;
  final Map<String, String> labelsTipo;
  final Map<String, (Color, Color)> colorsTipo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoriaCard({
    required this.categoria,
    required this.labelsTipo,
    required this.colorsTipo,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = colorsTipo[categoria.tipo] ??
        (const Color(0xFF6B7280), const Color(0xFFF3F4F6));

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.$2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.category_outlined,
                    size: 20, color: colors.$1),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.$2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labelsTipo[categoria.tipo] ?? categoria.tipo,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.$1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            categoria.nombre,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827)),
          ),
          if (categoria.codigo != null)
            Text(
              categoria.codigo!,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          if (categoria.descripcion != null) ...[
            const SizedBox(height: 4),
            Text(
              categoria.descripcion!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _ActionBtn(
                icon: Icons.edit_outlined,
                label: 'Editar',
                onTap: onEdit,
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.block_outlined,
                label: 'Desactivar',
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEE2E2),
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab de Productos ──────────────────────────────────────────────────────────
class _ProductosTab extends StatefulWidget {
  final MenuProvider provider;
  final void Function(ProductoRead) onEdit;
  final void Function(ProductoRead) onDelete;
  final void Function(ProductoRead) onConfigSucursal;

  const _ProductosTab({
    required this.provider,
    required this.onEdit,
    required this.onDelete,
    required this.onConfigSucursal,
  });

  @override
  State<_ProductosTab> createState() => _ProductosTabState();
}

class _ProductosTabState extends State<_ProductosTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const _labelsTipo = {
    'simple': 'Simple',
    'compuesto': 'Compuesto',
    'servicio': 'Servicio',
    'combo': 'Combo',
  };

  static const _labelsEstado = {
    'activo': 'Activo',
    'inactivo': 'Inactivo',
    'descontinuado': 'Descontinuado',
  };

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return Column(
      children: [
        // Barra de búsqueda y filtro de categorías
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => provider.setSearch(v),
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    hintStyle: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 13),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: Color(0xFF9CA3AF)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Color(0xFFD1D5DB))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Color(0xFFD1D5DB))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFF2563EB), width: 2)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Filtro por categoría
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String?>(
                  key: const ValueKey('dd_cat_filter'),
                  value: provider.categoriaFilter,
                  hint: const Text('Todas las categorías',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF9CA3AF))),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('Todas',
                            style: TextStyle(fontSize: 13))),
                    ...provider.categorias.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.nombre,
                              style: const TextStyle(fontSize: 13)),
                        )),
                  ],
                  onChanged: (v) => provider.setCategoriaFilter(v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lista de productos
        Expanded(
          child: provider.productos.isEmpty
              ? const _EmptyView(
                  icon: Icons.fastfood_outlined,
                  message: 'No hay productos',
                  sublabel: 'Crea un producto para comenzar',
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  child: Column(
                    children: provider.productos
                        .map((p) => _ProductoRow(
                              producto: p,
                              categorias: provider.categorias,
                              labelsTipo: _labelsTipo,
                              labelsEstado: _labelsEstado,
                              onEdit: () => widget.onEdit(p),
                              onDelete: () => widget.onDelete(p),
                              onConfigSucursal: () =>
                                  widget.onConfigSucursal(p),
                            ))
                        .toList(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ProductoRow extends StatelessWidget {
  final ProductoRead producto;
  final List<CategoriaRead> categorias;
  final Map<String, String> labelsTipo;
  final Map<String, String> labelsEstado;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onConfigSucursal;

  const _ProductoRow({
    required this.producto,
    required this.categorias,
    required this.labelsTipo,
    required this.labelsEstado,
    required this.onEdit,
    required this.onDelete,
    required this.onConfigSucursal,
  });

  @override
  Widget build(BuildContext context) {
    final categoria = categorias
        .where((c) => c.id == producto.categoriaId)
        .firstOrNull;

    final estadoColor = switch (producto.estado) {
      'activo' => (const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
      'inactivo' => (const Color(0xFF6B7280), const Color(0xFFF3F4F6)),
      'descontinuado' => (
          const Color(0xFFDC2626),
          const Color(0xFFFEE2E2)
        ),
      _ => (const Color(0xFF6B7280), const Color(0xFFF3F4F6)),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          // Ícono del producto
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.fastfood_outlined,
                size: 22, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      producto.nombre,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: estadoColor.$2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        labelsEstado[producto.estado] ?? producto.estado,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: estadoColor.$1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (categoria != null) ...[
                      Text(
                        categoria.nombre,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                      const Text(' · ',
                          style: TextStyle(color: Color(0xFF9CA3AF))),
                    ],
                    Text(
                      labelsTipo[producto.tipoProducto] ??
                          producto.tipoProducto,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                    if (producto.codigoInterno != null) ...[
                      const Text(' · ',
                          style: TextStyle(color: Color(0xFF9CA3AF))),
                      Text(
                        producto.codigoInterno!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ],
                ),
                // Chips de flags
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    if (producto.esVendible)
                      _Flag('Vendible', const Color(0xFF16A34A)),
                    if (producto.requiereInventario)
                      _Flag('Inventario', const Color(0xFF2563EB)),
                    if (producto.permiteDecimal)
                      _Flag('Decimal', const Color(0xFF7C3AED)),
                  ],
                ),
              ],
            ),
          ),

          // Acciones
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionBtn(
                icon: Icons.store_outlined,
                label: 'Sucursal',
                color: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF5F3FF),
                onTap: onConfigSucursal,
              ),
              const SizedBox(width: 6),
              _ActionBtn(
                icon: Icons.edit_outlined,
                label: 'Editar',
                onTap: onEdit,
              ),
              const SizedBox(width: 6),
              _ActionBtn(
                icon: Icons.block_outlined,
                label: 'Desactivar',
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEE2E2),
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  final String label;
  final Color color;

  const _Flag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// ── Widgets compartidos ────────────────────────────────────────────────────────
class _AddBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.add, size: 15, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color bgColor;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF374151),
    this.bgColor = const Color(0xFFF3F4F6),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sublabel;

  const _EmptyView({
    required this.icon,
    required this.message,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text(sublabel,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 40, color: Color(0xFFDC2626)),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}