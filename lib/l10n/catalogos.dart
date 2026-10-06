/// Nombres de los catálogos fijos —los 17 ODS y las competencias Enactus—
/// en el idioma activo.
///
/// Los catálogos los sirve la API (`/catalogs`) con su nombre en español. En
/// español se muestra tal cual lo manda el servidor, como siempre; en inglés
/// se traduce por el código (`ods_6`, `teamwork`), que no cambia nunca. Un
/// código que la app no conoce —uno agregado después en la base— se muestra
/// con el nombre del servidor en vez de quedar vacío.
library;

import 'textos.dart';

/// Título de un ODS por su código (`ods_1` … `ods_17`).
String tituloOds(String codigo, String delServidor) {
  if (Idioma.instancia.codigo == 'es') return delServidor;
  return switch (codigo) {
        'ods_1' => tr.ods1,
        'ods_2' => tr.ods2,
        'ods_3' => tr.ods3,
        'ods_4' => tr.ods4,
        'ods_5' => tr.ods5,
        'ods_6' => tr.ods6,
        'ods_7' => tr.ods7,
        'ods_8' => tr.ods8,
        'ods_9' => tr.ods9,
        'ods_10' => tr.ods10,
        'ods_11' => tr.ods11,
        'ods_12' => tr.ods12,
        'ods_13' => tr.ods13,
        'ods_14' => tr.ods14,
        'ods_15' => tr.ods15,
        'ods_16' => tr.ods16,
        'ods_17' => tr.ods17,
        _ => null,
      } ??
      delServidor;
}

/// Nombre de una competencia Enactus por su código.
String nombreCompetencia(String codigo, String delServidor) {
  if (Idioma.instancia.codigo == 'es') return delServidor;
  return switch (codigo) {
        'leadership' => tr.competenciaLeadership,
        'innovation' => tr.competenciaInnovation,
        'entrepreneurship' => tr.competenciaEntrepreneurship,
        'finance' => tr.competenciaFinance,
        'communication' => tr.competenciaCommunication,
        'pitch' => tr.competenciaPitch,
        'sustainability' => tr.competenciaSustainability,
        'artificial_intelligence' => tr.competenciaArtificialIntelligence,
        'teamwork' => tr.competenciaTeamwork,
        'user_centered_design' => tr.competenciaUserCenteredDesign,
        'project_management' => tr.competenciaProjectManagement,
        'impact_measurement' => tr.competenciaImpactMeasurement,
        _ => null,
      } ??
      delServidor;
}
