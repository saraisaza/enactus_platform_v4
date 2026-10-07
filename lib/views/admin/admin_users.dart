import 'package:flutter/material.dart';

import '../../l10n/textos.dart';
import '../../widgets/university_picker.dart';
import 'package:provider/provider.dart';

import '../../models/client.dart';
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
import 'student_assignments_dialog.dart';

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

  /// `null` = de cualquier cliente.
  String? _clientFilter;

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
    final lista = data.users(
        role: _roleFilter == _todos ? null : _roleFilter,
        clientId: _clientFilter);
    final clientes = data.clients.valueOrNull ?? const <Client>[];

    return TabBody(
      title: tr.tabUsuarios,
      subtitle: widget.isSuperAdmin
          ? tr.usuariosSubtituloSuper
          : tr.usuariosSubtitulo,
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.person_add, size: 18),
          label: Text(tr.usuariosNuevo),
          onPressed: () => _abrirFormulario(null),
        ),
      ],
      children: [
        const _ColaDeEliminacion(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in [_todos, ...Roles.all])
              ChoiceChip(
                label: Text(r == _todos ? tr.comunTodos : Roles.label(r)),
                selected: _roleFilter == r,
                selectedColor: AppColors.gold.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _roleFilter = r),
              ),
          ],
        ),
        if (clientes.isNotEmpty) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: DropdownButtonFormField<String?>(
              initialValue: _clientFilter,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr.usuariosFiltroCliente),
              items: [
                DropdownMenuItem<String?>(
                    value: null, child: Text(tr.usuariosTodosLosClientes)),
                for (final c in clientes)
                  DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _clientFilter = v),
            ),
          ),
        ],
        const SizedBox(height: 16),
        lista.when(
          loading: () => const CardListSkeleton(count: 5, height: 64),
          error: (e) => ErrorState(e, onRetry: () async {
            // Un filtro nuevo dispara su propio pedido; reintentar es volver
            // a tocar el mismo getter.
            setState(() {});
          }),
          data: (users) => users.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline,
                  message: tr.usuariosSinRol)
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

/// Cuentas que pidieron eliminarse y cuyos datos falta borrar.
///
/// La persona lo pide desde la app (Mi cuenta › Eliminar mi cuenta) y la cuenta
/// deja de funcionar en el acto; borrar los datos es este segundo paso, que
/// el equipo tiene que dar dentro del plazo que se le prometió (30 días). No
/// aparece nada mientras no haya solicitudes.
class _ColaDeEliminacion extends StatelessWidget {
  const _ColaDeEliminacion();

  static const _plazoDias = 30;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final solicitudes = data.deletionRequests.valueOrNull ?? const [];
    if (solicitudes.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.statusCritical),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            solicitudes.length == 1
                ? tr.usuariosUnaSolicitud
                : tr.usuariosSolicitudes(solicitudes.length),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            tr.usuariosSolicitudesTexto(_plazoDias),
            style: TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 8),
          for (final s in solicitudes) _FilaDeSolicitud(solicitud: s),
        ],
      ),
    );
  }
}

class _FilaDeSolicitud extends StatefulWidget {
  final DeletionRequest solicitud;
  const _FilaDeSolicitud({required this.solicitud});

  @override
  State<_FilaDeSolicitud> createState() => _FilaDeSolicitudState();
}

class _FilaDeSolicitudState extends State<_FilaDeSolicitud> {
  bool _borrando = false;

  Future<void> _borrar() async {
    final s = widget.solicitud;
    if (!await confirmDialog(
      context,
      tr.usuariosBorrarDatosDe(s.name),
      tr.usuariosBorrarDatosTexto,
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _borrando = true);
    try {
      await context.read<DataProvider>().purgeUser(s.id);
      if (mounted) showAppSnack(context, tr.usuariosDatosBorrados);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _borrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    final transcurridos = DateTime.now().difference(s.requestedAt).inDays;
    final quedan = _ColaDeEliminacion._plazoDias - transcurridos;
    final fecha =
        MaterialLocalizations.of(context).formatShortDate(s.requestedAt);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.name} · ${Roles.label(s.role)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${tr.usuariosPidioEl(s.email, fecha)} · '
                  '${quedan > 0 ? tr.usuariosQuedanDias(quedan) : tr.usuariosPlazoVencido}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: quedan > 0
                        ? AppColors.textMuted
                        : AppColors.statusCritical,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _borrando ? null : _borrar,
            child: Text(_borrando ? tr.usuariosBorrando : tr.usuariosBorrarDatos),
          ),
        ],
      ),
    );
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
          columns: [
            DataColumn(label: Text(tr.comunNombre)),
            DataColumn(label: Text(tr.perfilCorreoEtiqueta)),
            DataColumn(label: Text(tr.usuariosRol)),
            DataColumn(label: Text(tr.usuariosDetalle)),
            DataColumn(label: Text(tr.usuariosAcciones)),
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
                  DataCell(Text(_detalle(context, u))),
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
String _detalle(BuildContext context, AppUser u) {
  // Una cuenta de empresa se nombra por su empresa: «Open Learning» a secas
  // escondería con qué marca entra y a quién pertenece.
  final empresa = u.clientId == null
      ? null
      : context
          .watch<DataProvider>()
          .clients
          .valueOrNull
          ?.where((c) => c.id == u.clientId && !c.hasLaboratories)
          .firstOrNull;
  final partes = <String>[
    if (empresa != null)
      tr.usuariosDeEmpresa(empresa.name)
    else if (Roles.isStudentLike(u.role))
      StudentType.label(u.studentType),
    if (u.university.isNotEmpty) u.university,
    if (u.role == Roles.company && u.companyName.isNotEmpty) u.companyName,
    if (u.role == Roles.donor && (u.impactCode ?? '').isNotEmpty) u.impactCode!,
    if (u.role == Roles.lxd) tr.usuariosCalifica(_calificaEn(u)),
    if (u.city.isNotEmpty) u.city,
  ];
  return partes.join(' · ');
}

String _calificaEn(AppUser lxd) {
  final contextos = [
    if (lxd.canGradeOpenLearning) 'Open Learning',
    if (lxd.canGradeEnactus) 'eduXaction',
  ];
  return contextos.isEmpty ? tr.usuariosNinguno : contextos.join(', ');
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
    final detalle = _detalle(context, user);
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
              // Se puede encoger: "Asesor Académico" con la letra agrandada
              // no cabía junto al nombre a 360 dp.
              Flexible(
                child: StatusChip(
                  label: Roles.label(user.role),
                  color: AppColors.gold,
                  icon: Icons.badge_outlined,
                ),
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
        // Solo para estudiantes: es el único rol que recibe material. Para
        // el resto el botón no tendría a qué apuntar.
        if (Roles.isStudentLike(user.role))
          IconButton(
            icon: const Icon(Icons.assignment_ind_outlined, size: 18),
            color: AppColors.gold,
            tooltip: user.studentType == StudentType.openLearning
                ? tr.usuariosAsignarCursos
                : tr.usuariosAsignarLabs,
            onPressed: () => showStudentAssignmentsDialog(context, user),
          ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          color: AppColors.gold,
          tooltip: tr.comunEditar,
          onPressed: canEdit ? onEdit : null,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: AppColors.statusCritical,
          tooltip: tr.comunEliminar,
          onPressed: !canDelete
              ? null
              : () async {
                  final ok = await confirmDoubleDialog(
                    context,
                    tr.usuariosEliminar,
                    tr.usuariosEliminarTexto(user.name, Roles.label(user.role)),
                  );
                  if (!ok || !context.mounted) return;
                  try {
                    await data.deleteUser(user.id);
                    if (context.mounted) {
                      showSuccessCheck(context, tr.usuariosCuentaEliminada);
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
  /// El id de la universidad. Ya NO es un campo de texto: ver
  /// `UniversityPicker` y por qué no se puede escribir a mano.
  String? _universityId;

  /// Lo escrito en «Otra (¿cuál?)». Al guardar se vuelve una universidad del
  /// catálogo; nunca viaja como texto en la persona.
  final _otraUniversidad = TextEditingController();
  late final TextEditingController _career;
  late final TextEditingController _companyName;
  late final TextEditingController _impactCode;

  // Perfil libre de LXD y Mentor.
  late final Map<String, TextEditingController> _profile;

  late String _role;

  /// eduXaction, Open Learning o Empresa. «Empresa» no es un tipo más para el
  /// servidor: es una cuenta de Open Learning que pertenece a una empresa
  /// cliente, y por eso ve la plataforma con su marca.
  late String _tipoCuenta;
  static const _tipoEmpresa = 'empresa';

  /// El tipo que viaja al servidor.
  String get _studentType =>
      _tipoCuenta == _tipoEmpresa ? StudentType.openLearning : _tipoCuenta;

  /// La empresa cliente (estudiante de empresa, o LXD de una empresa).
  String? _clientId;
  String? _studentCity;
  String? _alliedCompanyId;
  late bool _canGradeOpenLearning;
  late bool _canGradeEnactus;

  bool _saving = false;
  ApiException? _error;

  bool get _isNew => widget.original == null;

  static Map<String, String> get _profileFields => {
    'company': tr.perfilCampoEmpresa,
    'position': tr.perfilCargo,
    'specialty': tr.perfilEspecialidad,
    'languages': tr.perfilIdiomas,
    'availability': tr.perfilDisponibilidad,
    'experience': tr.perfilExperiencia,
    'interests': tr.perfilIntereses,
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
    _career = TextEditingController(text: u?.career ?? '');
    _companyName = TextEditingController(text: u?.companyName ?? '');
    _impactCode = TextEditingController(text: u?.impactCode ?? '');
    _profile = {
      for (final key in _profileFields.keys)
        key: TextEditingController(text: '${u?.profile[key] ?? ''}'),
    };

    _role = u?.role ?? widget.creatableRoles.first;
    _clientId = u?.clientId;
    // Una cuenta de Open Learning con cliente es de una empresa: Enactus no
    // admite cuentas de Open Learning (lo valida el servidor).
    _tipoCuenta = u?.studentType == StudentType.openLearning && u?.clientId != null
        ? _tipoEmpresa
        : (u?.studentType ?? StudentType.enactus);
    // Al editar se parte de lo que ya tiene. Sin esto, abrir la ficha de
    // alguien y guardar sin tocar nada le BORRARÍA la universidad — el peor
    // tipo de pérdida de datos, porque no se hizo ningún cambio.
    _universityId = u?.universityId;
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
      _career,
      _companyName,
      _impactCode,
      _otraUniversidad,
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
          ValidationError(tr.usuariosNombreCorreoObligatorios));
      return;
    }
    // Al crear es obligatoria; al editar solo se valida si se escribió algo,
    // porque en blanco significa "dejala como está".
    if ((_isNew || _password.text.isNotEmpty) && _password.text.length < 6) {
      setState(() => _error = ValidationError(
          tr.usuariosContrasenaMinima));
      return;
    }
    final esDeEmpresa =
        Roles.isStudentLike(_role) && _tipoCuenta == _tipoEmpresa;
    if (esDeEmpresa && _clientId == null) {
      setState(() => _error = ValidationError(tr.usuariosEligaEmpresa));
      return;
    }
    final eligioOtra = _universityId == UniversityPicker.otra;
    if (eligioOtra && _otraUniversidad.text.trim().length < 3) {
      setState(() => _error = ValidationError(
          tr.usuariosEscribaInstitucion));
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
      // Se manda el id; el servidor escribe además el texto con el nombre
      // del catálogo (escritura doble, R2). Mandar texto desde acá volvería a
      // abrir la puerta que este cambio cierra.
      'universityId': _universityId,
      'career': _career.text.trim(),
      'companyName': _role == Roles.company ? _companyName.text.trim() : '',
      'impactCode': _role == Roles.donor ? _impactCode.text.trim() : null,
      // El tipo de estudiante es obligatorio para un estudiante y prohibido
      // para cualquier otro rol: es lo que separa eduXaction de Open Learning
      // en toda la API.
      'studentType': esEstudiante ? _studentType : null,
      'companyId': esPersonalDeEmpresa ? _alliedCompanyId : null,
      // El cliente se manda solo donde se elige: un estudiante de Open
      // Learning (de una empresa o de ninguna) y un LXD. Las cuentas de la red
      // Enactus no lo mandan: el servidor las deja en Enactus.
      if (esEstudiante && _tipoCuenta != StudentType.enactus)
        'clientId': esDeEmpresa ? _clientId : null,
      if (_role == Roles.lxd) 'clientId': _clientId,
      if (_role == Roles.lxd || _role == Roles.mentor)
        'profile': {
          for (final e in _profile.entries) e.key: e.value.text.trim(),
        },
    };

    try {
      // «Otra»: primero se agrega al catálogo —o se toma la que ya estaba,
      // si existía escrita de otra forma— y la persona apunta a esa fila.
      if (eligioOtra) {
        final otra = await data.createUniversity(_otraUniversidad.text.trim());
        campos['universityId'] = otra.id;
        if (mounted) setState(() => _universityId = otra.id);
      }

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
    final titulo = _isNew ? tr.usuariosNuevo : tr.usuariosEditar;
    final acciones = [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: Text(tr.comunCancelar),
      ),
      ElevatedButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? tr.comunGuardando : tr.comunGuardar),
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
                  tooltip: tr.comunCerrar,
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
            decoration: InputDecoration(labelText: tr.usuariosRol),
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
              tr.usuariosRolFijo(Roles.label(_role)),
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        const SizedBox(height: 12),
        _campo(_name, tr.usuariosNombreCompleto),
        const SizedBox(height: 12),
        _campo(_email, tr.ingresoCorreo),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          enabled: !_saving,
          obscureText: true,
          decoration: InputDecoration(
            labelText: _isNew ? tr.ingresoContrasena : tr.usuariosContrasenaNueva,
            helperText: _isNew
                ? tr.usuariosMinimoSeis
                : tr.usuariosDejeEnBlanco,
          ),
        ),
        const SizedBox(height: 12),
        _campo(_phone, tr.perfilTelefonoEtiqueta),
        if (!esEstudiante) ...[
          const SizedBox(height: 12),
          _campo(_city, tr.perfilCiudad),
        ],
        if (esEstudiante) ..._camposEstudiante(),
        if (_role == Roles.lxd) ..._camposLxd(data),
        if (_role == Roles.mentor) ..._camposMentor(data),
        if (_role == Roles.advisor) ...[
          const SizedBox(height: 12),
          UniversityPicker(
            value: _universityId,
            onChanged: (v) => setState(() => _universityId = v),
            otraController: _otraUniversidad,
            // Un asesor sin universidad no ve a NADIE, así que la ausencia no
            // es un estado neutro: se avisa acá y no al guardar.
            allowEmpty: true,
            emptyLabel: tr.usuariosSinUniversidadAsesor,
          ),
        ],
        if (_role == Roles.company) ...[
          const SizedBox(height: 12),
          _campo(_companyName, tr.usuariosNombreEmpresa),
        ],
        if (_role == Roles.donor) ...[
          const SizedBox(height: 12),
          _campo(_impactCode, tr.usuariosCodigoImpacto),
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
          decoration:
              InputDecoration(labelText: tr.usuariosTipoEstudiante),
          initialValue: _tipoCuenta,
          items: [
            for (final t in StudentType.all)
              DropdownMenuItem(value: t, child: Text(StudentType.label(t))),
            DropdownMenuItem(
                value: _tipoEmpresa, child: Text(tr.usuariosTipoEmpresa)),
          ],
          onChanged:
              _saving ? null : (v) => setState(() => _tipoCuenta = v!),
        ),
        const SizedBox(height: 4),
        Text(
          switch (_tipoCuenta) {
            _tipoEmpresa => tr.usuariosVeMarcaEmpresa,
            StudentType.openLearning => tr.usuariosSoloCursos,
            _ => tr.usuariosVeLabs,
          },
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        if (_tipoCuenta == _tipoEmpresa) ...[
          const SizedBox(height: 12),
          _selectorDeEmpresa(opcional: false),
        ],
        const SizedBox(height: 12),
        _campo(_cedula, tr.perfilCedula),
        const SizedBox(height: 12),
        UniversityPicker(
          value: _universityId,
          onChanged: (v) => setState(() => _universityId = v),
          otraController: _otraUniversidad,
          // Un estudiante Enactus DEBE tener universidad (INV-2); un Open
          // Learning no lleva, y eso es correcto, no un campo sin llenar.
          allowEmpty: _studentType != 'enactus',
          emptyLabel: _studentType == 'enactus'
              ? tr.usuariosElijaUniversidad
              : tr.usuariosSinUniversidadOL,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _studentCity,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tr.perfilCiudad,
            helperText: tr.usuariosCiudadAyuda,
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
        _campo(_career, tr.perfilCarrera),
      ];

  List<Widget> _camposLxd(DataProvider data) => [
        const SizedBox(height: 12),
        _selectorDeEmpresa(opcional: true),
        const SizedBox(height: 12),
        _empresaAliada(data,
            ayuda: tr.usuariosLxdEmpresa),
        for (final e in _profileFields.entries) ...[
          const SizedBox(height: 12),
          _campo(_profile[e.key]!, e.value),
        ],
        const SizedBox(height: 14),
        Text(tr.usuariosPermisoCalificar,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        Text(
          tr.usuariosCambioRegistrado,
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Open Learning', style: TextStyle(fontSize: 14)),
          subtitle: Text(tr.usuariosOLDefecto,
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
          subtitle: Text(tr.usuariosEduDefecto,
              style: TextStyle(fontSize: 12)),
          value: _canGradeEnactus,
          activeThumbColor: AppColors.gold,
          onChanged:
              _saving ? null : (v) => setState(() => _canGradeEnactus = v),
        ),
      ];

  List<Widget> _camposMentor(DataProvider data) => [
        const SizedBox(height: 12),
        Text(
          tr.usuariosMentorLab,
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        _empresaAliada(data,
            ayuda: tr.usuariosMentorEmpresa),
      ];

  /// La empresa cliente de la cuenta. Obligatoria para un estudiante de
  /// empresa; opcional para un LXD (sin empresa, es de eduXaction).
  Widget _selectorDeEmpresa({required bool opcional}) {
    final data = context.watch<DataProvider>();
    return data.clients.when(
      loading: () => const CardListSkeleton(count: 1, height: 56),
      error: (e) => ErrorBanner(e),
      data: (clientes) {
        // Enactus no va acá: sus cuentas llegan a él solas. Una empresa
        // desactivada no admite cuentas nuevas, pero si ya era la de esta
        // persona se sigue mostrando.
        final empresas = clientes
            .where((c) => !c.hasLaboratories && (c.active || c.id == _clientId))
            .toList();
        if (empresas.isEmpty && !opcional) {
          return Text(tr.usuariosSinEmpresasCliente,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.statusWarning));
        }
        return DropdownButtonFormField<String?>(
          initialValue:
              empresas.any((c) => c.id == _clientId) ? _clientId : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: opcional
                ? tr.usuariosEmpresaClienteOpcional
                : tr.usuariosEmpresaCliente,
            helperText: opcional
                ? tr.usuariosEmpresaClienteLxdAyuda
                : tr.usuariosEmpresaClienteAyuda,
            helperMaxLines: 3,
          ),
          items: [
            if (opcional)
              DropdownMenuItem<String?>(
                  value: null, child: Text(tr.usuariosNingunaEdu)),
            for (final c in empresas)
              DropdownMenuItem<String?>(
                value: c.id,
                child: Text(c.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _saving ? null : (v) => setState(() => _clientId = v),
        );
      },
    );
  }

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
              labelText: tr.usuariosEmpresaAliada,
              helperText: ayuda,
            ),
            items: [
              DropdownMenuItem<String?>(
                  value: null, child: Text(tr.usuariosNingunaEdu)),
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
