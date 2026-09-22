/**
 * Punto de entrada. Monta las vistas, las conecta al estado y arranca el
 * bucle de reproduccion. Todo lo demas cuelga de `ui/state.ts`.
 */

import './style.css';

import { CourtView2D } from './render2d/courtSvg.js';
import { CAMERA_PRESETS, Scene3D } from './render3d/scene.js';
import {
  PROJECTIONS,
  type ProjectionId,
} from './render2d/projections.js';
import { clearNode, el, mustGet } from './ui/dom.js';
import {
  attach3DInput,
  attachFrontInput,
  attachPlanInput,
} from './ui/dragInput.js';
import { createInspectorPanel } from './ui/inspector.js';
import type { PanelView } from './ui/panels.js';
import { createShotPanel } from './ui/panelSliders.js';
import {
  state,
  subscribe,
  update,
  type AppState,
  type LayoutId,
} from './ui/state.js';

const views = new Map<ProjectionId, CourtView2D>();
const panels: PanelView[] = [];
let scene3d: Scene3D | null = null;
let activePanel = 'shot';

// ------------------------------------------------------------- vistas 2D

const mount2D = (): void => {
  for (const projection of PROJECTIONS) {
    const host = mustGet(`viewport-${projection.id}`);
    const view = new CourtView2D(projection);
    host.appendChild(
      el('div', { class: 'viewport-label', text: projection.label }),
    );
    host.appendChild(view.svg);
    host.appendChild(
      el('div', { class: 'viewport-hint', text: projection.hint }),
    );
    views.set(projection.id, view);
  }

  // Modo de input A. La lateral se deja de solo lectura: descarta X, asi
  // que un clic ahi no puede decidir donde esta parado el jugador.
  attachPlanInput(views.get('plan')!);
  attachFrontInput(views.get('front')!);
};

// ------------------------------------------------------------- vista 3D

const mount3D = (): void => {
  const canvas = mustGet<HTMLCanvasElement>('canvas3d');
  try {
    scene3d = new Scene3D(canvas);
  } catch (err) {
    // Sin WebGL la app sigue siendo util: las tres vistas 2D lo cuentan
    // todo menos la sensacion de volumen.
    console.warn('WebGL no disponible, se sigue solo con las vistas 2D', err);
    mustGet('viewport-3d').appendChild(
      el('div', {
        class: 'viewport-hint',
        style: 'opacity:1;top:50%;text-align:center',
        text: 'Este navegador no puede dibujar 3D. Las vistas 2D siguen funcionando.',
      }),
    );
    return;
  }

  attach3DInput(scene3d);

  const host = mustGet('camera-presets');
  for (const preset of CAMERA_PRESETS) {
    const b = el('button', {
      class: 'btn',
      type: 'button',
      'data-camera': preset.id,
      text: preset.label,
    });
    b.addEventListener('click', () => {
      scene3d?.applyCameraPreset(preset.id);
      for (const other of host.querySelectorAll('[data-camera]')) {
        other.classList.toggle('btn--active', other === b);
      }
    });
    if (preset.id === 'behind') b.classList.add('btn--active');
    host.appendChild(b);
  }
};

// ------------------------------------------------------------- pestanas

const LAYOUTS: { id: LayoutId; label: string }[] = [
  { id: 'split', label: 'Todo' },
  { id: '3d', label: '3D' },
  { id: 'plan', label: 'Planta' },
  { id: 'front', label: 'Frontal' },
  { id: 'side', label: 'Lateral' },
];

const mountLayoutTabs = (): void => {
  const host = mustGet('layout-tabs');
  for (const layout of LAYOUTS) {
    const tab = el('button', {
      class: 'tab',
      type: 'button',
      role: 'tab',
      'data-layout': layout.id,
      text: layout.label,
    });
    tab.addEventListener('click', () => update({ layout: layout.id }));
    host.appendChild(tab);
  }
};

const syncLayout = (): void => {
  mustGet('viewports').dataset.layout = state.layout;
  for (const tab of document.querySelectorAll<HTMLElement>('[data-layout]')) {
    if (tab.classList.contains('tab')) {
      tab.setAttribute(
        'aria-selected',
        String(tab.dataset.layout === state.layout),
      );
    }
  }
};

// ------------------------------------------------------------- panel

const mountPanel = (): void => {
  panels.push(createShotPanel(), createInspectorPanel());

  const tabs = mustGet('panel-tabs');
  const body = mustGet('panel-body');

  for (const panel of panels) {
    const tab = el('button', {
      class: 'tab',
      type: 'button',
      role: 'tab',
      'data-panel': panel.id,
      text: panel.label,
    });
    tab.addEventListener('click', () => selectPanel(panel.id));
    tabs.appendChild(tab);
    body.appendChild(panel.root);
  }

  selectPanel(activePanel);
};

const selectPanel = (id: string): void => {
  activePanel = id;
  for (const panel of panels) {
    panel.root.hidden = panel.id !== id;
  }
  for (const tab of document.querySelectorAll<HTMLElement>('[data-panel]')) {
    tab.setAttribute('aria-selected', String(tab.dataset.panel === id));
  }
};

/** Añade un panel despues del arranque (lo usan las fases 6 y 9). */
export const registerPanel = (panel: PanelView): void => {
  panels.push(panel);
  const tab = el('button', {
    class: 'tab',
    type: 'button',
    role: 'tab',
    'data-panel': panel.id,
    text: panel.label,
  });
  tab.addEventListener('click', () => selectPanel(panel.id));
  mustGet('panel-tabs').appendChild(tab);
  mustGet('panel-body').appendChild(panel.root);
  panel.root.hidden = panel.id !== activePanel;
};

// ------------------------------------------------------------- barra sup.

const mountTopbarRight = (): void => {
  const host = mustGet('topbar-right');

  const models: { id: AppState['model']; label: string; title: string }[] = [
    {
      id: 'geometric',
      label: 'Geometrico',
      title: 'Reflexion ideal: sin gravedad, sin arrastre, sin perdida.',
    },
    {
      id: 'ballistic',
      label: 'Balistico',
      title: 'Gravedad, arrastre y COR. Lo que hace la pelota de verdad.',
    },
  ];

  const group = el('div', { class: 'layout-tabs' });
  for (const model of models) {
    const b = el('button', {
      class: 'tab',
      type: 'button',
      'data-model': model.id,
      title: model.title,
      text: model.label,
    });
    b.addEventListener('click', () => update({ model: model.id }));
    group.appendChild(b);
  }
  host.appendChild(group);
};

const syncTopbar = (): void => {
  for (const b of document.querySelectorAll<HTMLElement>('[data-model]')) {
    b.setAttribute('aria-selected', String(b.dataset.model === state.model));
  }
};

// ------------------------------------------------------------- timeline

let scrub: HTMLInputElement;
let timeLabel: HTMLElement;
let playButton: HTMLButtonElement;

const mountTimeline = (): void => {
  const host = mustGet('timeline');
  clearNode(host);

  playButton = el('button', {
    class: 'btn btn--icon',
    type: 'button',
    title: 'Reproducir (espacio)',
    text: '▶',
  });
  playButton.addEventListener('click', () => togglePlay());

  scrub = el('input', {
    type: 'range',
    min: 0,
    max: 1,
    step: 0.001,
    value: 0,
    'aria-label': 'Instante de la trayectoria',
  }) as HTMLInputElement;
  scrub.addEventListener('input', () => {
    update({ playing: false, playhead: Number(scrub.value) });
  });

  timeLabel = el('span', { class: 'timeline-time', text: '0.000 s' });

  const rate = el('select', { class: 'btn', 'aria-label': 'Velocidad' });
  for (const [label, value] of [
    ['1/20', 0.05],
    ['1/8', 0.125],
    ['1/4', 0.25],
    ['1/2', 0.5],
    ['1x', 1],
  ] as const) {
    const option = el('option', { value, text: label });
    if (value === state.playRate) option.setAttribute('selected', '');
    rate.appendChild(option);
  }
  rate.addEventListener('change', () =>
    update({ playRate: Number((rate as HTMLSelectElement).value) }),
  );

  host.append(playButton, scrub, timeLabel, rate);
};

const togglePlay = (): void => {
  if (!state.playing && state.playhead >= state.trajectory.totalTime - 1e-6) {
    update({ playhead: 0 });
  }
  update({ playing: !state.playing });
};

const syncTimeline = (): void => {
  const total = Math.max(state.trajectory.totalTime, 1e-3);
  scrub.max = String(total);
  if (document.activeElement !== scrub) scrub.value = String(state.playhead);
  timeLabel.textContent = `${state.playhead.toFixed(3)} s / ${total.toFixed(2)} s`;
  playButton.textContent = state.playing ? '❚❚' : '▶';
};

// ------------------------------------------------------------- redibujo

const redraw = (changed?: ReadonlySet<string>): void => {
  const trajectoryChanged = !changed || changed.has('trajectory');
  if (!changed || changed.has('model')) syncTopbar();

  for (const view of views.values()) {
    view.draw(state.trajectory, {
      playhead: state.playhead,
      origin: state.shot.origin,
      aim: state.aim,
    });
  }

  if (scene3d) {
    // Reconstruir el tubo cuesta; el playhead se mueve cada frame y no
    // necesita tocarlo.
    if (trajectoryChanged) {
      scene3d.trajectory.setTrajectory(state.trajectory);
      scene3d.trajectory.setOrigin(state.shot.origin);
    }
    if (!changed || changed.has('aim')) scene3d.trajectory.setAim(state.aim);
    scene3d.trajectory.setPlayhead(state.playhead);
    scene3d.invalidate();
  }

  syncTimeline();
  for (const panel of panels) {
    panel.sync((changed ?? new Set()) as ReadonlySet<keyof AppState>);
  }
};

// ------------------------------------------------------------- bucle

let lastFrame = 0;

const frame = (now: number): void => {
  const dt = lastFrame === 0 ? 0 : (now - lastFrame) / 1000;
  lastFrame = now;

  if (state.playing) {
    const total = state.trajectory.totalTime;
    const next = state.playhead + dt * state.playRate;
    if (next >= total) update({ playhead: total, playing: false });
    else update({ playhead: next });
  }

  scene3d?.render();
  requestAnimationFrame(frame);
};

// ------------------------------------------------------------- teclado

const mountKeyboard = (): void => {
  window.addEventListener('keydown', (e) => {
    const target = e.target as HTMLElement | null;
    if (target && /^(INPUT|SELECT|TEXTAREA)$/.test(target.tagName)) return;
    if (e.key === ' ') {
      e.preventDefault();
      togglePlay();
    }
  });
};

// ------------------------------------------------------------- arranque

const boot = (): void => {
  mount2D();
  mount3D();
  mountLayoutTabs();
  mountTopbarRight();
  mountPanel();
  mountTimeline();
  mountKeyboard();

  subscribe((_s, changed) => {
    if (changed.has('layout')) {
      syncLayout();
      scene3d?.resize();
    }
    redraw(changed as ReadonlySet<string>);
  });

  syncLayout();
  redraw();
  requestAnimationFrame(frame);
};

boot();
