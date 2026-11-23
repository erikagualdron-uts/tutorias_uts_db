// Volume data for measuring performance (spec 023): the size of a real institution, synthetic, with
// disabled and deleted rows mixed in. Deterministic: two runs on an empty database give the same rows.
//   LOAD_SEED_CONFIRM=yes DATABASE_URL=postgresql://.../tutorias_load npm run seed:load
// It refuses to run unless the database name ends in `_load` and the confirmation is given.
import 'dotenv/config';
import argon2 from 'argon2';
import { PrismaPg } from '@prisma/adapter-pg';
import { Prisma, PrismaClient } from '@prisma/client';

const url = process.env.DATABASE_URL ?? '';
const dbName = url ? new URL(url).pathname.slice(1) : '';
if (process.env.LOAD_SEED_CONFIRM !== 'yes' || !dbName.endsWith('_load')) {
  console.error(`seed:load only runs with LOAD_SEED_CONFIRM=yes on a database named *_load (got "${dbName}").`);
  process.exit(1);
}

const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });

const PASSWORD = 'Clave1234'; // the e2e tests' password
const PQRS_TYPES = [1, 2, 3, 4].map((n) => `a1b2c3d4-0002-4000-8000-00000000000${n}`);
const DAY_MS = 86_400_000;
const WEEKS = 12;
const HOURS_OFFSET = 5; // America/Bogota is UTC-5, no daylight saving

// Counts (docs: specs/023-quality/data-model.md)
const TEACHERS = 40;
const STUDENTS = 500;
const ROOMS = 60;
const ACTIVE_MODULES = 150;
const CLOSED_MODULES = 50; // 25 in each closed period
const DELETED_MODULES = 10;

// Deterministic uuid: a prefix per table and a counter.
const PREFIX = { user: 1, period: 2, location: 3, room: 4, module: 5, schedule: 6, session: 7, enrollment: 8, pqrs: 9, conv: 10, msg: 11, event: 12, notif: 13, holiday: 14, req: 15 };
const id = (kind: keyof typeof PREFIX, n: number) =>
  `${PREFIX[kind].toString(16).padStart(8, '0')}-0000-4000-8000-${n.toString(16).padStart(12, '0')}`;

// Small deterministic generator (mulberry32).
let state = 20260101;
const rand = () => {
  state = (state + 0x6d2b79f5) | 0;
  let t = Math.imul(state ^ (state >>> 15), 1 | state);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const int = (max: number) => Math.floor(rand() * max);

async function insert<T>(rows: T[], create: (chunk: T[]) => Promise<unknown>, size = 2000) {
  for (let i = 0; i < rows.length; i += size) await create(rows.slice(i, i + size));
}

async function main() {
  if ((await prisma.user.count()) > 0) throw new Error('The load database already has users; recreate it first.');
  const passwordHash = await argon2.hash(PASSWORD); // one hash for everyone
  const verified = new Date('2025-01-01T00:00:00Z');
  const at = (iso: string) => new Date(iso);

  // Users ----------------------------------------------------------------------------------------
  const cae = id('user', 0);
  const teacher = (t: number) => id('user', 1 + t);
  const student = (s: number) => id('user', 1 + TEACHERS + s);
  await prisma.user.createMany({
    data: [
      { id: cae, email: 'cae@correo.uts.edu.co', role: 'SUPERADMIN' as const },
      ...Array.from({ length: TEACHERS }, (_, t) => ({ id: teacher(t), email: `docente${t}@correo.uts.edu.co`, role: 'TEACHER' as const, status: t >= TEACHERS - 3 ? ('INACTIVE' as const) : ('ACTIVE' as const) })),
      ...Array.from({ length: STUDENTS }, (_, s) => ({
        id: student(s),
        email: `estudiante${s}@uts.edu.co`,
        role: 'STUDENT' as const,
        // the last 25 are disabled and the 10 after them deleted; the first students stay usable
        status: s >= STUDENTS - 35 && s < STUDENTS - 10 ? ('INACTIVE' as const) : ('ACTIVE' as const),
        deletedAt: s >= STUDENTS - 10 ? at('2026-06-01T00:00:00Z') : null,
      })),
    ].map((u) => ({ passwordHash, emailVerifiedAt: verified, ...u })),
  });
  await prisma.teacherProfile.createMany({ data: Array.from({ length: TEACHERS }, (_, t) => ({ userId: teacher(t), firstName: `Docente${t}`, lastName: 'Carga', phone: `300${String(1000000 + t)}` })) });
  await prisma.studentProfile.createMany({ data: Array.from({ length: STUDENTS }, (_, s) => ({ userId: student(s), firstName: `Estudiante${s}`, lastName: 'Carga', program: `Programa ${s % 12}` })) });

  // Periods, places, holidays ---------------------------------------------------------------------
  const periods = [
    { n: 1, name: 'Carga 2025-1', startsOn: '2025-02-03', endsOn: '2025-06-27', first: '2025-03-03', status: 'CLOSED' as const },
    { n: 2, name: 'Carga 2025-2', startsOn: '2025-07-21', endsOn: '2025-12-12', first: '2025-08-04', status: 'CLOSED' as const },
    { n: 3, name: 'Carga 2026-2', startsOn: '2026-07-20', endsOn: '2027-01-31', first: '2026-10-19', status: 'ACTIVE' as const },
  ];
  await prisma.academicPeriod.createMany({
    data: periods.map((p) => ({
      id: id('period', p.n), name: p.name, startsOn: at(`${p.startsOn}T00:00:00Z`), endsOn: at(`${p.endsOn}T00:00:00Z`), status: p.status,
      ...(p.status === 'CLOSED' && { closedAt: at(`${p.endsOn}T23:00:00Z`), closedBy: 'AUTOMATIC' as const }),
    })),
  });
  await prisma.location.createMany({ data: Array.from({ length: 15 }, (_, l) => ({ id: id('location', l), name: `Sede ${l + 1}` })) });
  const capacity = (r: number) => 15 + ((r * 3) % 46);
  await prisma.room.createMany({ data: Array.from({ length: ROOMS }, (_, r) => ({ id: id('room', r), locationId: id('location', r % 15), name: `Salón ${r + 1}`, capacity: capacity(r) })) });
  const holidayDates = ['2026-11-02', '2026-11-16', '2026-12-08', '2026-12-25', '2027-01-01'];
  await prisma.holiday.createMany({ data: holidayDates.map((d, h) => ({ id: id('holiday', h), date: at(`${d}T00:00:00Z`), name: `Festivo ${d}` })) });

  // Modules: a grid of 40 weekly cells (Mon-Fri x 8 hours). The cells are chosen so no teacher and no
  // room overlaps (the database enforces it) and a student can take up to 12 modules without clashes.
  const total = ACTIVE_MODULES + CLOSED_MODULES;
  const periodOf = (m: number) => (m < ACTIVE_MODULES ? 3 : m < ACTIVE_MODULES + 25 ? 1 : 2);
  const teacherOf = (m: number) => m % TEACHERS;
  const roomOf = (m: number) => m % ROOMS;
  const cells = (m: number) => {
    const c1 = (3 * m + 5 * Math.floor(m / TEACHERS)) % 40;
    return [c1, (c1 + 7) % 40];
  };
  const deleted = (m: number) => m >= ACTIVE_MODULES - DELETED_MODULES && m < ACTIVE_MODULES;
  const deletedAt = at('2026-09-01T00:00:00Z');

  await prisma.module.createMany({
    data: Array.from({ length: total }, (_, m) => ({
      id: id('module', m), periodId: id('period', periodOf(m)), name: `Módulo ${m + 1}`, description: 'Tutoría de carga', teacherId: teacher(teacherOf(m)), roomId: id('room', roomOf(m)),
      deletedAt: deleted(m) ? deletedAt : null,
    })),
  });
  const slots = Array.from({ length: total }, (_, m) => cells(m).map((cell, i) => ({ m, i, day: (cell % 5) + 1, startMinute: (7 + Math.floor(cell / 5)) * 60 })));
  await prisma.moduleSchedule.createMany({
    data: slots.flat().map((s) => ({
      id: id('schedule', s.m * 2 + s.i), moduleId: id('module', s.m), periodId: id('period', periodOf(s.m)), teacherId: teacher(teacherOf(s.m)), roomId: id('room', roomOf(s.m)),
      dayOfWeek: s.day, startMinute: s.startMinute, endMinute: s.startMinute + 60, deletedAt: deleted(s.m) ? deletedAt : null,
    })),
  });

  // Sessions: 12 weekly occurrences per slot. Holidays cancel; every 37th is cancelled by the teacher;
  // the first slot of the even modules of the first group is moved to Saturday in week 4.
  const sessions: Prisma.ModuleSessionCreateManyInput[] = [];
  const sessionIds = new Map<number, string[]>(); // module -> its live session ids (for absences)
  let n = 0;
  for (const s of slots.flat()) {
    const first = at(`${periods[periodOf(s.m) - 1].first}T00:00:00Z`).getTime();
    for (let w = 0; w < WEEKS; w++) {
      const startsAt = new Date(first + (w * 7 + s.day - 1) * DAY_MS + (s.startMinute / 60 + HOURS_OFFSET) * 3_600_000);
      const date = startsAt.toISOString().slice(0, 10);
      const holiday = holidayDates.indexOf(date);
      const moved = !s.i && w === 3 && s.m < TEACHERS && s.m % 2 === 0;
      const byTeacher = holiday < 0 && !moved && n % 37 === 0;
      const sid = id('session', n++);
      const shifted = new Date(startsAt.getTime() + (moved ? (6 - s.day) * DAY_MS : 0));
      sessions.push({
        id: sid, moduleId: id('module', s.m), scheduleId: id('schedule', s.m * 2 + s.i), teacherId: teacher(teacherOf(s.m)), roomId: id('room', roomOf(s.m)),
        originalStartsAt: startsAt, startsAt: shifted, endsAt: new Date(shifted.getTime() + 3_600_000),
        status: holiday >= 0 || byTeacher ? 'CANCELLED' : moved ? 'RESCHEDULED' : 'SCHEDULED',
        ...(holiday >= 0 && { cancelReason: 'HOLIDAY' as const, holidayId: id('holiday', holiday) }),
        ...(byTeacher && { cancelReason: 'TEACHER' as const }),
        deletedAt: deleted(s.m) ? deletedAt : null,
      });
      if (!deleted(s.m) && holiday < 0 && !byTeacher) sessionIds.set(s.m, [...(sessionIds.get(s.m) ?? []), sid]);
    }
  }
  await insert(sessions, (data) => prisma.moduleSession.createMany({ data }));

  // Enrollments: each student takes 2..12 modules of the active period without clashing cells and
  // within the room capacity; student 0 takes exactly 10. A few are cancelled with an effective date.
  const liveModules = Array.from({ length: ACTIVE_MODULES - DELETED_MODULES }, (_, m) => m);
  const seats = new Map(liveModules.map((m) => [m, capacity(roomOf(m))]));
  const enrollments: { id: string; studentId: string; moduleId: string; status: 'ACTIVE' | 'CANCELLED'; cancelledAt?: Date; effectiveUntil?: Date }[] = [];
  for (let s = 0; s < STUDENTS; s++) {
    const want = s === 0 ? 10 : 2 + ((s * 7) % 11);
    const busy = new Set<number>();
    for (let tries = 0, got = 0; got < want && tries < 400; tries++) {
      const m = liveModules[int(liveModules.length)];
      const own = cells(m);
      if (busy.has(own[0]) || busy.has(own[1]) || !seats.get(m)) continue;
      own.forEach((c) => busy.add(c));
      seats.set(m, seats.get(m)! - 1);
      got++;
      const cancelled = s > 0 && enrollments.length % 13 === 0;
      enrollments.push({ id: id('enrollment', enrollments.length), studentId: student(s), moduleId: id('module', m), status: cancelled ? 'CANCELLED' : 'ACTIVE', ...(cancelled && { cancelledAt: at('2026-11-10T15:00:00Z'), effectiveUntil: at('2026-11-17T00:00:00Z') }) });
    }
  }
  await insert(enrollments, (data) => prisma.enrollment.createMany({ data }));
  const live = enrollments.filter((e) => e.status === 'ACTIVE');
  const absences = new Map<string, { enrollmentId: string; sessionId: string }>();
  while (absences.size < 300) {
    const e = live[int(live.length)];
    const list = sessionIds.get(Number.parseInt(e.moduleId.slice(-12), 16))!;
    const sessionId = list[int(list.length)];
    absences.set(`${e.id}:${sessionId}`, { enrollmentId: e.id, sessionId });
  }
  await prisma.sessionAbsence.createMany({ data: [...absences.values()] });

  // PQRS: 200 in the three states; the ones in review or resolved carry CAE replies.
  const authors = [...Array.from({ length: 120 }, (_, s) => student(10 + s)), ...Array.from({ length: 30 }, (_, t) => teacher(t))];
  const statusOf = (p: number) => (p < 80 ? 'FILED' : p < 140 ? 'IN_REVIEW' : 'RESOLVED') as 'FILED' | 'IN_REVIEW' | 'RESOLVED';
  const created = (p: number) => new Date(at('2026-08-01T14:00:00Z').getTime() + p * 6 * 3_600_000);
  await prisma.pqrs.createMany({
    data: Array.from({ length: 200 }, (_, p) => ({
      id: id('pqrs', p), authorId: authors[p % authors.length], typeId: PQRS_TYPES[p % 4], subject: `Asunto de carga ${p + 1}`, description: `Descripción de la solicitud ${p + 1}. `.repeat(8),
      status: statusOf(p), clientRequestId: id('req', p), createdAt: created(p),
      ...(statusOf(p) !== 'FILED' && { reviewedAt: new Date(created(p).getTime() + 3_600_000) }),
      ...(statusOf(p) === 'RESOLVED' && { resolvedAt: new Date(created(p).getTime() + 7_200_000) }),
    })),
  });
  await prisma.pqrsMessage.createMany({
    data: Array.from({ length: 200 }, (_, p) => p).filter((p) => statusOf(p) !== 'FILED').flatMap((p) => [0, 1].map((k) => ({ pqrsId: id('pqrs', p), authorId: cae, body: `Respuesta ${k + 1} del CAE a la solicitud ${p + 1}.`, createdAt: new Date(created(p).getTime() + (k + 1) * 1_800_000) }))),
  });

  // Chats: 60 direct conversations and one per live module; the first module chat is the big one.
  const members: { conversationId: string; userId: string }[] = [];
  const conversations: { id: string; type: 'DIRECT' | 'MODULE'; moduleId?: string; directKey?: string }[] = [];
  for (let d = 0; d < 60; d++) {
    const a = student(10 + d);
    const b = teacher(d % 30);
    conversations.push({ id: id('conv', d), type: 'DIRECT', directKey: [a, b].sort().join(':') });
    members.push({ conversationId: id('conv', d), userId: a }, { conversationId: id('conv', d), userId: b });
  }
  const byModule = new Map<number, string[]>();
  for (const e of live) {
    const m = Number.parseInt(e.moduleId.slice(-12), 16);
    byModule.set(m, [...(byModule.get(m) ?? []), e.studentId]);
  }
  for (const m of liveModules) {
    const conv = id('conv', 100 + m);
    conversations.push({ id: conv, type: 'MODULE', moduleId: id('module', m) });
    for (const u of [teacher(teacherOf(m)), ...(byModule.get(m) ?? [])]) members.push({ conversationId: conv, userId: u });
  }
  await prisma.conversation.createMany({ data: conversations.map((c) => ({ ...c, lastMessageAt: at('2026-11-20T12:00:00Z') })) });
  await insert(members, (data) => prisma.conversationMember.createMany({ data }));
  const biggest = id('conv', 100 + [...byModule.entries()].sort((a, b) => b[1].length - a[1].length)[0][0]);
  const messages: { id: string; conversationId: string; senderId: string; body: string; clientMessageId: string; createdAt: Date }[] = [];
  const bySender = new Map<string, string[]>();
  for (const m of members) bySender.set(m.conversationId, [...(bySender.get(m.conversationId) ?? []), m.userId]);
  for (const c of conversations) {
    const count = c.id === biggest ? 1500 : 5 + int(16);
    const users = bySender.get(c.id)!;
    for (let k = 0; k < count; k++)
      messages.push({ id: id('msg', messages.length), conversationId: c.id, senderId: users[int(users.length)], body: `Mensaje ${k + 1} de la conversación de carga.`, clientMessageId: id('msg', 1_000_000 + messages.length), createdAt: new Date(at('2026-09-01T12:00:00Z').getTime() + k * 600_000) });
  }
  await insert(messages, (data) => prisma.message.createMany({ data }));

  // Notices: 100 outbox events fanned out to 20 students each (2,000), half of them read.
  await prisma.outboxEvent.createMany({ data: Array.from({ length: 100 }, (_, e) => ({ id: id('event', e), type: 'SESSION_CANCELLED_TEACHER' as const, moduleId: id('module', e), payload: {}, processedAt: at('2026-11-01T12:00:00Z') })) });
  await insert(
    Array.from({ length: 2000 }, (_, k) => k),
    (ks) => prisma.notification.createMany({ data: ks.map((k) => ({ id: id('notif', k), userId: student(10 + (k % 400)), eventId: id('event', Math.floor(k / 20)), type: 'SESSION_CANCELLED_TEACHER' as const, moduleId: id('module', Math.floor(k / 20)), locale: 'es' as const, title: 'Sesión cancelada', body: `Se canceló una sesión del módulo ${Math.floor(k / 20) + 1}.`, readAt: k % 2 ? at('2026-11-02T12:00:00Z') : null, createdAt: new Date(at('2026-11-01T12:00:00Z').getTime() + k * 60_000) })) }),
  );

  console.info(`Load data ready in ${dbName}: ${total} modules, ${sessions.length} sessions, ${enrollments.length} enrollments, ${messages.length} messages.`);
}

main()
  .catch((error) => {
    console.error(error, (error as { cause?: unknown }).cause);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
