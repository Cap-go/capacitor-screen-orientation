/* eslint-disable no-undef */

import './style.css';
import { ScreenOrientation } from '@capgo/capacitor-screen-orientation';

const plugin = ScreenOrientation;
const state = {};

const actions = [
  {
    id: 'get-orientation',
    label: 'Get current orientation',
    description: 'Calls orientation() to get the current screen orientation.',
    inputs: [],
    run: async () => {
      const result = await plugin.orientation();
      return result;
    },
  },
  {
    id: 'lock-orientation',
    label: 'Lock orientation',
    description: 'Locks the screen to the specified orientation.',
    inputs: [
      {
        name: 'orientation',
        label: 'Orientation',
        type: 'select',
        value: 'portrait',
        options: [
          { value: 'any', label: 'Any' },
          { value: 'natural', label: 'Natural' },
          { value: 'landscape', label: 'Landscape' },
          { value: 'portrait', label: 'Portrait' },
          { value: 'portrait-primary', label: 'Portrait Primary' },
          { value: 'portrait-secondary', label: 'Portrait Secondary' },
          { value: 'landscape-primary', label: 'Landscape Primary' },
          { value: 'landscape-secondary', label: 'Landscape Secondary' },
        ],
      },
      {
        name: 'bypassOrientationLock',
        label: 'Bypass orientation lock (enable motion tracking)',
        type: 'checkbox',
        value: false,
      },
    ],
    run: async (values) => {
      await plugin.lock({
        orientation: values.orientation,
        bypassOrientationLock: values.bypassOrientationLock,
      });
      return `Orientation locked to: ${values.orientation}`;
    },
  },
  {
    id: 'unlock-orientation',
    label: 'Unlock orientation',
    description: 'Unlocks the screen orientation, allowing free rotation.',
    inputs: [],
    run: async () => {
      await plugin.unlock();
      return 'Orientation unlocked.';
    },
  },
  {
    id: 'start-tracking',
    label: 'Start orientation tracking',
    description: 'Starts tracking physical device orientation using motion sensors.',
    inputs: [
      {
        name: 'bypassOrientationLock',
        label: 'Bypass orientation lock',
        type: 'checkbox',
        value: true,
      },
    ],
    run: async (values) => {
      await plugin.startOrientationTracking({
        bypassOrientationLock: values.bypassOrientationLock,
      });
      return 'Orientation tracking started.';
    },
  },
  {
    id: 'stop-tracking',
    label: 'Stop orientation tracking',
    description: 'Stops tracking physical device orientation.',
    inputs: [],
    run: async () => {
      await plugin.stopOrientationTracking();
      return 'Orientation tracking stopped.';
    },
  },
  {
    id: 'check-lock-status',
    label: 'Check orientation lock status',
    description: 'Checks if device orientation lock is enabled by comparing physical and UI orientation.',
    inputs: [],
    run: async () => {
      const result = await plugin.isOrientationLocked();
      return result;
    },
  },
  {
    id: 'add-listener',
    label: 'Add orientation change listener',
    description: 'Registers a listener for screen orientation changes. Results will appear in the output.',
    inputs: [],
    run: async () => {
      if (state.listener) {
        await state.listener.remove();
      }
      state.listener = await plugin.addListener('screenOrientationChange', (result) => {
        const output = document.getElementById('plugin-output');
        output.textContent = `Orientation changed: ${JSON.stringify(result, null, 2)}`;
      });
      return 'Listener added. Rotate your device to see orientation changes.';
    },
  },
  {
    id: 'remove-listeners',
    label: 'Remove all listeners',
    description: 'Removes all registered event listeners.',
    inputs: [],
    run: async () => {
      await plugin.removeAllListeners();
      state.listener = null;
      return 'All listeners removed.';
    },
  },
  {
    id: 'get-version',
    label: 'Get plugin version',
    description: 'Returns the native plugin version.',
    inputs: [],
    run: async () => {
      const result = await plugin.getPluginVersion();
      return result;
    },
  },
];

const actionSelect = document.getElementById('action-select');
const formContainer = document.getElementById('action-form');
const descriptionBox = document.getElementById('action-description');
const runButton = document.getElementById('run-action');
const output = document.getElementById('plugin-output');

function buildForm(action) {
  formContainer.innerHTML = '';
  if (!action.inputs?.length) {
    const note = document.createElement('p');
    note.className = 'no-input-note';
    note.textContent = 'This action does not require any inputs.';
    formContainer.appendChild(note);
    return;
  }
  action.inputs.forEach((input) => {
    const fieldWrapper = document.createElement('div');
    fieldWrapper.className = input.type === 'checkbox' ? 'form-field inline' : 'form-field';

    const label = document.createElement('label');
    label.textContent = input.label;
    label.htmlFor = `field-${input.name}`;

    let field;
    switch (input.type) {
      case 'textarea': {
        field = document.createElement('textarea');
        field.rows = input.rows || 4;
        break;
      }
      case 'select': {
        field = document.createElement('select');
        (input.options || []).forEach((option) => {
          const opt = document.createElement('option');
          opt.value = option.value;
          opt.textContent = option.label;
          if (input.value !== undefined && option.value === input.value) {
            opt.selected = true;
          }
          field.appendChild(opt);
        });
        break;
      }
      case 'checkbox': {
        field = document.createElement('input');
        field.type = 'checkbox';
        field.checked = Boolean(input.value);
        break;
      }
      case 'number': {
        field = document.createElement('input');
        field.type = 'number';
        if (input.value !== undefined && input.value !== null) {
          field.value = String(input.value);
        }
        break;
      }
      default: {
        field = document.createElement('input');
        field.type = 'text';
        if (input.value !== undefined && input.value !== null) {
          field.value = String(input.value);
        }
      }
    }

    field.id = `field-${input.name}`;
    field.name = input.name;
    field.dataset.type = input.type || 'text';

    if (input.placeholder && input.type !== 'checkbox') {
      field.placeholder = input.placeholder;
    }

    if (input.type === 'checkbox') {
      fieldWrapper.appendChild(field);
      fieldWrapper.appendChild(label);
    } else {
      fieldWrapper.appendChild(label);
      fieldWrapper.appendChild(field);
    }

    formContainer.appendChild(fieldWrapper);
  });
}

function getFormValues(action) {
  const values = {};
  (action.inputs || []).forEach((input) => {
    const field = document.getElementById(`field-${input.name}`);
    if (!field) return;
    switch (input.type) {
      case 'number': {
        values[input.name] = field.value === '' ? null : Number(field.value);
        break;
      }
      case 'checkbox': {
        values[input.name] = field.checked;
        break;
      }
      default: {
        values[input.name] = field.value;
      }
    }
  });
  return values;
}

function setAction(action) {
  descriptionBox.textContent = action.description || '';
  buildForm(action);
  output.textContent = 'Ready to run the selected action.';
}

function populateActions() {
  actionSelect.innerHTML = '';
  actions.forEach((action) => {
    const option = document.createElement('option');
    option.value = action.id;
    option.textContent = action.label;
    actionSelect.appendChild(option);
  });
  setAction(actions[0]);
}

actionSelect.addEventListener('change', () => {
  const action = actions.find((item) => item.id === actionSelect.value);
  if (action) {
    setAction(action);
  }
});

runButton.addEventListener('click', async () => {
  const action = actions.find((item) => item.id === actionSelect.value);
  if (!action) return;
  const values = getFormValues(action);
  try {
    const result = await action.run(values);
    if (result === undefined) {
      output.textContent = 'Action completed.';
    } else if (typeof result === 'string') {
      output.textContent = result;
    } else {
      output.textContent = JSON.stringify(result, null, 2);
    }
  } catch (error) {
    output.textContent = `Error: ${error?.message ?? error}`;
  }
});

populateActions();
