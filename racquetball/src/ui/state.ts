/**
 * El estado de la app: un solo objeto y un emit(). No hay framework.
 *
 * Los parametros del tiro son la fuente de verdad; `shot` y `trajectory`
 * son derivados y se recalculan aqui, en un unico sitio, cada vez que
 * cambia algo que los afecta. Los tres modos de input editan estos mismos
 * campos, asi que cambiar de modo nunca pierde el tiro actual.
 */

import { DEFAULT_CONTACT_HEIGHT, COURT, SPEED } from '../core/constants.js';
import { clampToCourt } from '../core/court.js';
import { simulate } from '../core/engine.js';
import type {
  PhysicsModel,
  Shot,
  SimOptions,
  Trajectory,
  Vec3,
} from '../core/types.js';
import { fromAzimuthElevation, normalize, sub, v3 } from '../core/vec3.js';

export type LayoutId = 'split' | '3d' | 'plan' | 'front' | 'side';
export type InputMode = 'drag' | 'sliders' | 'presets';

export interface AppState {
  // --- parametros del tiro (fuente de verdad) ---
  origin: Vec3;
  azimuthDeg: number;
  elevationDeg: number;
  speed: number;
  model: PhysicsModel;
  /** Preset cargado, si el tiro no se ha tocado despues. */
  presetId: string | null;

  // --- derivados ---
  shot: Shot;
  trajectory: Trajectory;

  // --- reproduccion ---
  playhead: number;
  playing: boolean;
  playRate: number;

  // --- vistas ---
  layout: LayoutId;
  mirror: boolean;
  serveMode: boolean;

  // --- input ---
  inputMode: InputMode;
  /** Punto de mira en la pared frontal, si el modo clic+arrastre lo fijo. */
  aim: Vec3 | null;
}

export type Listener = (state: AppState, changed: ReadonlySet<keyof AppState>) => void;

const SHOT_KEYS: readonly (keyof AppState)[] = [
  'origin',
  'azimuthDeg',
  'elevationDeg',
  'speed',
  'model',
];

export const deriveShot = (s: {
  origin: Vec3;
  azimuthDeg: number;
  elevationDeg: number;
  speed: number;
}): Shot => ({
  origin: clampToCourt(s.origin),
  direction: fromAzimuthElevation(s.azimuthDeg, s.elevationDeg),
  speed: s.speed,
});

export const simOptionsFor = (model: PhysicsModel): SimOptions => ({ model });

const initialOrigin = v3(COURT.width / 2, DEFAULT_CONTACT_HEIGHT, 8.2);
const initialShot = deriveShot({
  origin: initialOrigin,
  azimuthDeg: 0,
  elevationDeg: 4,
  speed: SPEED.default,
});

export const state: AppState = {
  origin: initialOrigin,
  azimuthDeg: 0,
  elevationDeg: 4,
  speed: SPEED.default,
  model: 'geometric',
  presetId: null,

  shot: initialShot,
  trajectory: simulate(initialShot, { model: 'geometric' }),

  playhead: 0,
  playing: false,
  playRate: 0.25,

  layout: 'split',
  mirror: false,
  serveMode: false,

  inputMode: 'sliders',
  aim: null,
};

const listeners = new Set<Listener>();

export const subscribe = (fn: Listener): (() => void) => {
  listeners.add(fn);
  return () => listeners.delete(fn);
};

const emit = (changed: Set<keyof AppState>): void => {
  for (const fn of listeners) fn(state, changed);
};

/**
 * Unica via de escritura. Recalcula los derivados cuando hace falta y
 * avisa a los suscriptores con la lista de lo que cambio, para que cada
 * vista redibuje solo lo suyo.
 */
export const update = (patch: Partial<AppState>): void => {
  const changed = new Set<keyof AppState>();

  for (const key of Object.keys(patch) as (keyof AppState)[]) {
    const next = patch[key];
    if (next === undefined) continue;
    if (Object.is(state[key], next)) continue;
    // @ts-expect-error indice generico sobre una union de tipos de campo
    state[key] = next;
    changed.add(key);
  }

  if (changed.size === 0) return;

  const shotChanged = SHOT_KEYS.some((k) => changed.has(k));
  if (shotChanged) {
    state.shot = deriveShot(state);
    state.trajectory = simulate(state.shot, simOptionsFor(state.model));
    changed.add('shot');
    changed.add('trajectory');
    if (state.playhead > state.trajectory.totalTime) {
      state.playhead = state.trajectory.totalTime;
      changed.add('playhead');
    }
  }

  emit(changed);
};

/** Fuerza un redibujo completo (cambio de tema, de tamano, de jugada). */
export const refresh = (): void => {
  emit(new Set(Object.keys(state) as (keyof AppState)[]));
};

/**
 * Apunta a un punto concreto: recalcula azimut y elevacion desde el origen.
 * Lo usan el modo clic+arrastre y el solver inverso.
 */
export const aimAt = (target: Vec3, speed?: number): void => {
  const dir = normalize(sub(target, state.origin));
  if (dir.x === 0 && dir.y === 0 && dir.z === 0) return;
  const elevationDeg = (Math.asin(Math.max(-1, Math.min(1, dir.y))) * 180) / Math.PI;
  const azimuthDeg = (Math.atan2(dir.x, -dir.z) * 180) / Math.PI;
  update({
    azimuthDeg,
    elevationDeg,
    aim: target,
    presetId: null,
    ...(speed !== undefined ? { speed } : {}),
  });
};
