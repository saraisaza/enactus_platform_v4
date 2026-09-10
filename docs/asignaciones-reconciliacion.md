# Reconciliación de universidades — tiene fecha, y es antes de R3

**Abierta el 10 de septiembre de 2026, con el despliegue de R1.**

## Por qué hay una ventana, y por qué se cierra sola

R1 crea `universities` y rellena `users.university_id`, pero **las lecturas
siguen yendo por texto**. Eso significa que hoy:

- un estudiante mal mapeado —o mandado a «Sin asignar»— **sigue siendo
  visible** para su asesor, porque la visibilidad todavía compara
  `users.university`;
- un asesor sin universidad **sigue viendo a su gente**, por la misma razón.

En **R3** las lecturas pasan a `university_advisors` y a `university_id`. A
partir de ese despliegue:

- el estudiante mal mapeado **desaparece** del portal de su asesor;
- el asesor sin fila en `university_advisors` **no ve a nadie**.

Ninguna de las dos cosas lanza un error. Las dos se ven como «todavía no hay
estudiantes», que es el mismo síntoma que este trabajo entero viene a quitar.

**La ventana entre R1 y R3 es el tiempo de reconciliar, y solo existe porque
R1 se desplegó por su cuenta.** Si los dos fueran el mismo despliegue no
habría dónde arreglar los datos: pasarían de estar mal en silencio a estar mal
y además invisibles.

## Condiciones para poder desplegar R3

Las cuatro salen del reporte (`backend/scripts/reporte-universidades.sql`) y
las cuatro tienen que dar cero.

| # | Condición | De dónde sale |
|---|---|---|
| 1 | **Cero personas en «Sin asignar»** | bloque 4 del reporte |
| 2 | **Cero asesores fuera de `university_advisors`** | bloque 5 — la más urgente: en R3 no verían a nadie |
| 3 | **Cero pares candidatos sin resolver** | bloque 3 — cada uno se fusiona o se declara distinto |
| 4 | **Cero filas donde texto e id no coinciden** | bloque 6 — la condición literal de R3 |

La 3 admite dos desenlaces, y hay que elegir uno: **fusionar** (el reporte
trae el SQL escrito) o **declarar que son universidades distintas**. Dejarlo
sin decidir no es un tercer desenlace: es la condición 3 sin cumplir.

## Cómo se corre el reporte

```bash
# Sobre staging o producción, por la Lambda de administración (ver RUNBOOK,
# «`enactus-db-admin` — operar la base privada»).
```

En local, lo ejercita `backend/tests/universidades.test.ts`, que además
comprueba que cada bloque **ejecute**: un `.sql` suelto se rompe en silencio
cuando cambia una columna, y un reporte que nadie corre lleva tres migraciones
roto sin que se note.

## Lo que NO cierra esta reconciliación

Que las cuatro condiciones den cero **no** significa que los datos estén bien:
significa que texto e id dicen lo mismo. Si alguien tenía la universidad
equivocada desde antes, la va a seguir teniendo — solo que ahora en las dos
representaciones a la vez.

Eso no es alcance de R1..R4. Se menciona para que nadie lea «reconciliación
completa» como «datos verificados».
