import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'employees_provider.dart';
import 'widgets/employee_field.dart';
import 'widgets/add_employee_modal.dart';
import 'widgets/edit_employee_modal.dart';
import 'widgets/employee_detail_modal.dart';

class EmployeesPage extends StatelessWidget {
  final EmployeesProvider provider;

  const EmployeesPage({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: const _EmployeesView(),
    );
  }
}

class _EmployeesView extends StatelessWidget {
  const _EmployeesView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeesProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Empleados',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Gestion de usuarios y roles',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280))),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: provider,
                    child: const AddEmployeeModal(),
                  ),
                ),
                icon: const Icon(Icons.person_add_outlined, size: 16),
                label: const Text('Nuevo Empleado'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // Filtros
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              _FiltroChip(
                label: 'Todos',
                selected: provider.filtroEstado == null &&
                    provider.filtroRol == null,
                onTap: () {
                  provider.setFiltroEstado(null);
                  provider.setFiltroRol(null);
                },
              ),
              const SizedBox(width: 8),
              _FiltroChip(
                label: 'Activos',
                selected: provider.filtroEstado == 'activo',
                onTap: () => provider.setFiltroEstado(
                    provider.filtroEstado == 'activo' ? null : 'activo'),
              ),
              const SizedBox(width: 8),
              _FiltroChip(
                label: 'Suspendidos',
                selected: provider.filtroEstado == 'suspendido',
                onTap: () => provider.setFiltroEstado(
                    provider.filtroEstado == 'suspendido'
                        ? null
                        : 'suspendido'),
              ),
              const SizedBox(width: 8),
              _FiltroChip(
                label: 'Admins',
                selected: provider.filtroRol == 'admin_empresa',
                onTap: () => provider.setFiltroRol(
                    provider.filtroRol == 'admin_empresa'
                        ? null
                        : 'admin_empresa'),
              ),
              const Spacer(),
              Text('${provider.total} usuarios',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Tabla
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFEF4444), size: 40),
                          const SizedBox(height: 8),
                          Text(provider.error!,
                              style: const TextStyle(
                                  color: Color(0xFF6B7280))),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: provider.reload,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  : provider.perfiles.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.group_outlined,
                                  size: 48, color: Color(0xFFD1D5DB)),
                              SizedBox(height: 12),
                              Text('No se encontraron empleados',
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 14)),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: _EmployeesTable(
                                      provider: provider),
                                ),
                              ),
                            ),
                            // Paginacion
                            if (provider.totalPages > 1)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 24),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.end,
                                  children: [
                                    Text(
                                        'Pagina ${provider.page} de ${provider.totalPages}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF6B7280))),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.chevron_left,
                                          size: 20),
                                      onPressed: provider.hasPrevPage
                                          ? provider.prevPage
                                          : null,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.chevron_right,
                                          size: 20),
                                      onPressed: provider.hasNextPage
                                          ? provider.nextPage
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
        ),
      ],
    );
  }
}

// ─── Tabla ────────────────────────────────────────────────────────────────────

class _EmployeesTable extends StatelessWidget {
  final EmployeesProvider provider;

  const _EmployeesTable({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(3),   // Nombre
            1: FlexColumnWidth(3),   // Email
            2: FlexColumnWidth(1.5), // Rol
            3: FlexColumnWidth(1.5), // Estado
            4: FlexColumnWidth(1.5), // Acciones
          },
          children: [
            // Header
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
              children: [
                _HeaderCell('Nombre'),
                _HeaderCell('Email'),
                _HeaderCell('Rol'),
                _HeaderCell('Estado'),
                _HeaderCell('Acciones'),
              ],
            ),
            // Rows
            ...provider.perfiles.map((p) => TableRow(
                  decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  children: [
                    // Nombre + Avatar
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFEEF2FF),
                              child: Text(
                                p.nombreCompleto.isNotEmpty
                                    ? p.nombreCompleto[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6366F1)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(p.nombreCompleto,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Email
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(p.email,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF4B5563)),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    // Rol
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: RolBadge(rol: p.rolGlobal),
                      ),
                    ),
                    // Estado
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: EstadoBadge(estado: p.estado),
                      ),
                    ),
                    // Acciones
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _ActionBtn(
                              icon: Icons.visibility_outlined,
                              tooltip: 'Ver detalle',
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) =>
                                    ChangeNotifierProvider.value(
                                  value: provider,
                                  child: EmployeeDetailModal(perfil: p),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _ActionBtn(
                              icon: Icons.edit_outlined,
                              tooltip: 'Editar',
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) =>
                                    ChangeNotifierProvider.value(
                                  value: provider,
                                  child: EditEmployeeModal(perfil: p),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;

  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280))),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFF374151)),
        ),
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFEEF2FF)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF6366F1)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF374151))),
      ),
    );
  }
}