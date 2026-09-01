import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/colombia_cities.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';

/// Gestión de cuentas.
///
/// El filtro por rol lo aplica el SERVIDOR (`/users?role=`), no un `where`
/// sobre una lista ya traída: con la base entera en el navegador daba igual,
/// pero contra una API paginada filtrar después de paginar muestra "los de
/// esta página que además son mentores", que no es lo mismo que "los
/// mentores".
class AdminUsers extends StatefulWidget {
  final bool isSuperAdmin;
  const AdminUsers({super.key, required this.isSuperAdmin});

  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  static const _todos = 'todos';
  String _roleFilter = _todos;

  List<String> get _creatableRoles => [
        if (widget.isSuperAdmin) Roles.admin,
        Roles.student,
        Roles.alumni,
        Roles.lxd,
        Roles.mentor,
        Roles.advisor,
        Roles.company,
        Roles.donor,
      ];

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lista =
        data.users(role: _roleFilter == _todos ? null : _roleFilter);

    return TabBody(
      title: 'Usuarios',
      subtitle: widget.isSuperAdmin
          ? 'Crea y elimina cualquier tipo de cuenta (incluidos admins)'
          : 'Crea cuentas de estudiantes, LXD, mentores, asesores, empresas y '
              'donantes',
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Nuevo usuario'),
          onPressed: () => _abrirFormulario(null),
        ),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in [_todos, ...Roles.all])
              ChoiceChip(
                label: Text(r == _todos ? 'Todos' : Roles.label(r)),
                selected: _roleFilter == r,
                selectedColor: AppColors.gold.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _roleFilter = r),
              ),
          ],
        ),
        const SizedBox(height: 16),
        lista.when(
          loading: () => const CardListSkeleton(count: 5, height: 64),
          error: (e) => ErrorState(e, onRetry: () async {
            // Un filtro nuevo dispara su propio pedido; reintentar es volver
            // a tocar el mismo getter.
            setState(() {});
          }),
          data: (users) => users.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline,
                  message: 'No hay cuentas con ese rol.')
              : _UsersList(
                  users: users,
                  isSuperAdmin: widget.isSuperAdmin,
                  onEdit: _abrirFormulario,
                ),
        ),
      ],
    );
  }

  Future<void> _abrirFormulario(AppUser? user) async {
    final guardado = await showUserDialog(
      context,
      user: user,
      creatableRoles: _creatableRoles,
      isSuperAdmin: widget.isSuperAdmin,
    );
    if (guardado && mounted) setState(() {});
  }
}

/// La tabla en pantallas anchas; tarjetas apiladas cuando no cabe.
///
/// Una tabla de cinco columnas dentro de un scroll horizontal no está rota,
/// pero en un teléfono obliga a arrastrar de lado para leer cada fila.
class _UsersList extends StatelessWidget {
  final List<AppUser> users;
  final bool isSuperAdmin;
  final void Function(AppUser) onEdit;

  const _UsersList({
    required this.users,
    required this.isSuperAdmin,
    required this.onEdit,
  });

  /// Nadie elimina Super Admins; solo el Super Admin elimina admins.
  bool _canDelete(AppUser u) {
    if (u.role == Roles.superAdmin) return false;
    if (u.role == Roles.admin) return isSuperAdmin;
    return true;
  }

  bool _canEdit(AppUser u) => u.role != Roles.superAdmin;

  @override
  Widget build(BuildContext context) {
    if (context.breakpoint != AppBreakpoint.expanded) {
      return Column(
        children: [
          for (final u in users)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UserCard(
                user: u,
                canEdit: _canEdit(u),
                canDelete: _canDelete(u),
                onEdit: () => onEdit(u),
              ),
            ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Nombre')),
            DataColumn(label: Text('Correo')),
            DataColumn(label: Text('Rol')),
            DataColumn(label: Text('Detalle')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: [
            for (final u in users)
              DataRow(
                color: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.hovered)
                        ? AppColors.gold.withValues(alpha: 0.06)
                        : null),
                cells: [
                  DataCell(Text(u.name)),
                  DataCell(Text(u.email)),
                  DataCell(Text(Roles.label(u.role))),
                  DataCell(Text(_detalle(u))),
                  DataCell(_Acciones(
                    user: u,
                    canEdit: _canEdit(u),
                    canDelete: _canDelete(u),
                    onEdit: () => onEdit(u),
                  )),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Lo que distingue a esta persona, en una línea.
///
/// Sale de lo que YA trae la fila. Antes cada celda cruzaba laboratorios,
/// empresas y cursos por su cuenta: con la base en memoria eran búsquedas
/// gratis, contra la red serían varias peticiones por fila.
String _detalle(AppUser u) {
  final partes = <String>[
    if (Roles.isStudentLike(u.role)) StudentType.label(u.studentType),
    if (u.university.isNotEmpty) u.university,
    if (u.role == Roles.company && u.companyName.isNotEmpty) u.companyName,
    if (u.role == Roles.donor && (u.impactCode ?? '').isNotEmpty) u.impactCode!,
    if (u.role == Roles.lxd) 'Califica: ${_calificaEn(u)}',
    if (u.city.isNotEmpty) u.city,
  ];
  return partes.join(' · ');
}

String _calificaEn(AppUser lxd) {
  final contextos = [
    if (lxd.canGradeOpenLearning) 'Open Learning',
    if (lxd.canGradeEnactus) 'eduXaction',
  ];
  return contextos.isEmpty ? 'ninguno' : contextos.join(', ');
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;

  const _UserCard({
    required this.user,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final detalle = _detalle(user);
    return HoverCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(user.name, radius: 17),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text(user.email,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              StatusChip(
                label: Roles.label(user.role),
                color: AppColors.gold,
                icon: Icons.badge_outlined,
              ),
            ],
          ),
          if (detalle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(detalle,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: _Acciones(
              user: user,
              canEdit: canEdit,
              canDelete: canDelete,
              onEdit: onEdit,
            ),
          ),
        ],
      ),
    );
  }
}

class _Acciones extends StatelessWidget {
  final AppUser user;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;

  const _Acciones({
    required this.user,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataProvider>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          color: AppColors.gold,
          tooltip: 'Editar',
          onPressed: canEdit ? onEdit : null,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: AppColors.statusCritical,
          tooltip: 'Eliminar',
          onPressed: !canDelete
              ? null
              : () async {
                  final ok = await confirmDoubleDialog(
                    context,
                    'Eliminar usuario',
                    'Vas a eliminar a ${user.name} (${Roles.label(user.role)}).',
                  );
                  if (!ok || !context.mounted) return;
                  try {
                    await data.deleteUser(user.id);
                    if (context.mounted) {
                      showSuccessCheck(context, 'Cuenta eliminada ✓');
                    }
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      showAppSnack(context, e.message, error: true);
                    }
                  }
                },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Formulario de cuenta
// ---------------------------------------------------------------------------

/// Crea o edita una cuenta. Devuelve `true` si se guardó.
Future<bool> showUserDialog(
  BuildContext context, {
  AppUser? user,
  required List<String> creatableRoles,
  required bool isSuperAdmin,
}) async {
  final guardado = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UserFormDialog(
      original: user,
      creatableRoles: creatableRoles,
      isSuperAdmin: isSuperAdmin,
    ),
  );
  return guardado ?? false;
}

class _UserFormDialog extends StatefulWidget {
  final AppUser? original;
  final List<String> creatableRoles;
  final bool isSuperAdmin;

  const _UserFormDialog({
    this.original,
    required this.creatableRoles,
    required this.isSuperAdmin,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _password = TextEditingController();
  late final TextEditingController _phone;
  late final TextEditingController _cedula;
  late final TextEditingController _city;
  late final TextEditingController _university;
  late final TextEditingController _career;
  late final TextEditingController _companyName;
  late final TextEditingController _impactCode;

  // Perfil libre de LXD y Mentor.
  late final Map<String, TextEditingController> _profile;

  late String _role;
  late String _studentType;
  String? _studentCity;
  String? _alliedCompanyId;
  late bool _canGradeOpenLearning;
  late bool _canGradeEnactus;

  bool _saving = false;
  ApiException? _error;

  bool get _isNew => widget.original == null;

  static const _profileFields = {
    'company': 'Empresa',
    'position': 'Cargo',
    'specialty': 'Especialidad',
    'languages': 'Idiomas',
    'availability': 'Disponibilidad',
    'experience': 'Experiencia',
    'interests': 'Intereses',
  };

  @override
  void initState() {
    super.initState();
    final u = widget.original;
    _name = TextEditingController(text: u?.name ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _cedula = TextEditingController(text: u?.cedula ?? '');
    _city = TextEditingController(text: u?.city ?? '');
    _university = TextEditingController(text: u?.university ?? '');
    _career = TextEditingController(text: u?.career ?? '');
    _companyName = TextEditingController(text: u?.companyName ?? '');
    _impactCode = TextEditingController(text: u?.impactCode ?? '');
    _profile = {
      for (final key in _profileFields.keys)
        key: TextEditingController(text: '${u?.profile[key] ?? ''}'),
    };

    _role = u?.role ?? widget.creatableRoles.first;
    _studentType = u?.studentType ?? StudentType.enactus;
    // La ciudad del estudiante sale de un catálogo cerrado: el mapa necesita
    // coordenadas reales. Un valor viejo que no esté cae a "sin elegir" en vez
    // de reventar.
    _studentCity =
        colombiaCityByName(u?.city ?? '') == null ? null : u!.city;
    _alliedCompanyId = u?.companyId;
    _canGradeOpenLearning = u?.canGradeOpenLearning ?? true;
    _canGradeEnactus = u?.canGradeEnactus ?? false;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _password,
      _phone,
      _cedula,
      _city,
      _university,
      _career,
      _companyName,
      _impactCode,
      ..._profile.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final nombre = _name.text.trim();
    final correo = _email.text.trim();
    if (nombre.isEmpty || correo.isEmpty) {
      setState(() => _error =
          const ValidationError('El nombre y el correo son obligatorios.'));
      return;
    }
    // Al crear es obligatoria; al editar solo se valida si se escribió algo,
    // porque en blanco significa "dejala como está".
    if ((_isNew || _password.text.isNotEmpty) && _password.text.length < 6) {
      setState(() => _error = const ValidationError(
          'La contraseña necesita al menos 6 caracteres.'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final data = context.read<DataProvider>();
    final esEstudiante = Roles.isStudentLike(_role);
    final esPersonalDeEmpresa = _role == Roles.lxd || _role == Roles.mentor;

    final campos = <String, dynamic>{
      'name': nombre,
      'email': correo,
      'phone': _phone.text.trim(),
      'cedula': _cedula.text.trim(),
      'city': esEstudiante ? (_studentCity ?? '') : _city.text.trim(),
      'university': _university.text.trim(),
      'career': _career.text.trim(),
      'companyName': _role == Roles.company ? _companyName.text.trim() : '',
      'impactCode': _role == Roles.donor ? _impactCode.text.trim() : null,
      // El tipo de estudiante es obligatorio para un estudiante y prohibido
      // para cualquier otro rol: es lo que separa eduXaction de Open Learning
      // en toda la API.
      'studentType': esEstudiante ? _studentType : null,
      'companyId': esPersonalDeEmpresa ? _alliedCompanyId : null,
      if (_role == Roles.lxd || _role == Roles.mentor)
        'profile': {
          for (final e in _profile.entries) e.key: e.value.text.trim(),
        },
    };

    try {
      final AppUser guardado;
      if (_isNew) {
        guardado = await data.createUser({
          ...campos,
          'role': _role,
          'password': _password.text,
        });
      } else {
        // El rol NO se manda al editar: cambiarlo movería la cuenta de
        // alcance —y con ella su acceso— sin que se note. Se crea otra.
        //
        // La contraseña solo viaja si se escribió una nueva. Mandarla vacía
        // la reemplazaría por nada; no mandarla la deja como está.
        guardado = await data.updateUser(widget.original!.id, {
          ...campos,
          if (_password.text.isNotEmpty) 'password': _password.text,
        });
      }

      // Los permisos de calificar van por su propio endpoint, que deja
      // registro de quién los cambió. Por eso no se aceptan en el alta ni en
      // el parcheo general, y por eso van en una segunda llamada.
      if (_role == Roles.lxd &&
          (guardado.canGradeOpenLearning != _canGradeOpenLearning ||
              guardado.canGradeEnactus != _canGradeEnactus)) {
        await data.setCanGrade(
          guardado.id,
          openLearning: _canGradeOpenLearning,
          enactus: _canGradeEnactus,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _isNew ? 'Nuevo usuario' : 'Editar usuario';
    final acciones = [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      ElevatedButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Guardando…' : 'Guardar'),
      ),
    ];

    if (context.isCompact) {
      return Dialog.fullscreen(
        backgroundColor: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: AppColors.background,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar',
                  onPressed:
                      _saving ? null : () => Navigator.pop(context, false),
                ),
                title: Text(titulo, style: const TextStyle(fontSize: 17)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
                  child: _form(),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [acciones[0], const SizedBox(width: 8), acciones[1]],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(titulo, style: const TextStyle(fontSize: 18)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(child: _form()),
      ),
      actions: acciones,
    );
  }

  Widget _form() {
    final data = context.watch<DataProvider>();
    final esEstudiante = Roles.isStudentLike(_role);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) ...[
          ErrorBanner(_error!),
          const SizedBox(height: 12),
        ],
        if (_isNew)
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Rol'),
            items: [
              for (final r in widget.creatableRoles)
                DropdownMenuItem(value: r, child: Text(Roles.label(r))),
            ],
            onChanged: _saving ? null : (v) => setState(() => _role = v!),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Rol: ${Roles.label(_role)} — para cambiarlo, se crea otra '
              'cuenta. Cambiarlo acá movería su acceso sin que se note.',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        const SizedBox(height: 12),
        _campo(_name, 'Nombre completo'),
        const SizedBox(height: 12),
        _campo(_email, 'Correo electrónico'),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          enabled: !_saving,
          obscureText: true,
          decoration: InputDecoration(
            labelText: _isNew ? 'Contraseña' : 'Contraseña nueva (opcional)',
            helperText: _isNew
                ? 'Mínimo 6 caracteres.'
                : 'Dejala en blanco para no cambiarla. Cambiarla cierra las '
                    'sesiones abiertas de esa persona.',
          ),
        ),
        const SizedBox(height: 12),
        _campo(_phone, 'Teléfono'),
        if (!esEstudiante) ...[
          const SizedBox(height: 12),
          _campo(_city, 'Ciudad'),
        ],
        if (esEstudiante) ..._camposEstudiante(),
        if (_role == Roles.lxd) ..._camposLxd(data),
        if (_role == Roles.mentor) ..._camposMentor(data),
        if (_role == Roles.advisor) ...[
          const SizedBox(height: 12),
          _campo(_university, 'Universidad'),
        ],
        if (_role == Roles.company) ...[
          const SizedBox(height: 12),
          _campo(_companyName, 'Nombre de la empresa'),
        ],
        if (_role == Roles.donor) ...[
          const SizedBox(height: 12),
          _campo(_impactCode, 'Código de impacto único'),
        ],
      ],
    );
  }

  Widget _campo(TextEditingController controller, String label) => TextField(
        controller: controller,
        enabled: !_saving,
        decoration: InputDecoration(labelText: label),
      );

  List<Widget> _camposEstudiante() => [
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _studentType,
          decoration:
              const InputDecoration(labelText: 'Tipo de estudiante'),
          items: [
            for (final t in StudentType.all)
              DropdownMenuItem(value: t, child: Text(StudentType.label(t))),
          ],
          onChanged:
              _saving ? null : (v) => setState(() => _studentType = v!),
        ),
        const SizedBox(height: 4),
        Text(
          _studentType == StudentType.openLearning
              ? 'Solo ve los cursos que le asignes. Sin laboratorios ni Ruta '
                  'de Impacto.'
              : 'Ve Laboratorios y su Ruta de Impacto (se asignan desde el '
                  'laboratorio).',
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        _campo(_cedula, 'Cédula'),
        const SizedBox(height: 12),
        _campo(_university, 'Universidad'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _studentCity,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Ciudad',
            helperText: 'De dónde es — la ubica en el Mapa de Estudiantes',
          ),
          items: [
            for (final c in colombiaCities)
              DropdownMenuItem(
                value: c.name,
                child: Text('${c.name} · ${c.department}',
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _saving ? null : (v) => setState(() => _studentCity = v),
        ),
        const SizedBox(height: 12),
        _campo(_career, 'Carrera'),
      ];

  List<Widget> _camposLxd(DataProvider data) => [
        const SizedBox(height: 12),
        _empresaAliada(data,
            ayuda: 'Si este LXD es de una empresa aliada, sus cursos quedan '
                'atribuidos a ella.'),
        for (final e in _profileFields.entries) ...[
          const SizedBox(height: 12),
          _campo(_profile[e.key]!, e.value),
        ],
        const SizedBox(height: 14),
        const Text('Permiso de calificar',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const Text(
          'Cada cambio queda registrado con quién lo hizo.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Open Learning', style: TextStyle(fontSize: 14)),
          subtitle: const Text('Activado por defecto: es quien califica ahí',
              style: TextStyle(fontSize: 12)),
          value: _canGradeOpenLearning,
          activeThumbColor: AppColors.gold,
          onChanged: _saving
              ? null
              : (v) => setState(() => _canGradeOpenLearning = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('eduXaction', style: TextStyle(fontSize: 14)),
          subtitle: const Text('Desactivado por defecto: ahí no califica',
              style: TextStyle(fontSize: 12)),
          value: _canGradeEnactus,
          activeThumbColor: AppColors.gold,
          onChanged:
              _saving ? null : (v) => setState(() => _canGradeEnactus = v),
        ),
      ];

  List<Widget> _camposMentor(DataProvider data) => [
        const SizedBox(height: 12),
        const Text(
          'El laboratorio se asigna desde la pestaña "Laboratorios" (un '
          'laboratorio puede tener varios mentores).',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        _empresaAliada(data,
            ayuda: 'Si este Mentor es de una empresa aliada, queda atribuido '
                'a ella.'),
      ];

  Widget _empresaAliada(DataProvider data, {required String ayuda}) {
    return data.users(role: Roles.company).when(
          loading: () => const CardListSkeleton(count: 1, height: 56),
          error: (e) => ErrorBanner(e),
          data: (empresas) => DropdownButtonFormField<String?>(
            initialValue:
                empresas.any((c) => c.id == _alliedCompanyId)
                    ? _alliedCompanyId
                    : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Empresa aliada (opcional)',
              helperText: ayuda,
            ),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('Ninguna (de eduXaction)')),
              for (final c in empresas)
                DropdownMenuItem<String?>(
                  value: c.id,
                  child: Text(
                      c.companyName.isEmpty ? c.name : c.companyName,
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged:
                _saving ? null : (v) => setState(() => _alliedCompanyId = v),
          ),
        );
  }
}
