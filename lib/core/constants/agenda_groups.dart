/// Marcador del grupo "Agenda general" que el mapper asigna a las sesiones de
/// recintos físicos (ver `session_mapper.dart`). No es texto visible: sirve como
/// clave estable para agrupar y filtrar, y la UI lo traduce con
/// `context.l10n.agendaGeneral` al mostrarlo (ver `agenda_screen.dart`). Los
/// demás grupos llevan el nombre real de la sede, que viene del API y no se
/// traduce.
const String kAgendaGeneralGroup = '\u0000ovum:agenda_general';
