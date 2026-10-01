import { fetchNui } from "./fetchNui.js";

const optionsWrapper = document.getElementById("options-wrapper");

function onClick() {
  // when nuifocus is disabled after a click, the hover event is never released
  this.style.pointerEvents = "none";

  fetchNui("select", [this.targetType, this.targetId, this.zoneId]);
  // is there a better way to handle this? probably
  setTimeout(() => (this.style.pointerEvents = "auto"), 100);
}

export function createOptions(type, data, id, zoneId) {
  if (data.hide) return;

  const option = document.createElement("div");

  const iconEl = document.createElement("i");
  iconEl.className = `fa-fw ${data.icon} option-icon`;
  if (data.iconColor && /^#?[a-zA-Z0-9]+$/.test(data.iconColor)) {
    iconEl.style.color = data.iconColor;
  }
  const labelEl = document.createElement("p");
  labelEl.className = "option-label";
  labelEl.textContent = data.label;
  option.appendChild(iconEl);
  option.appendChild(labelEl);
  option.className = "option-container";
  option.targetType = type;
  option.targetId = id;
  option.zoneId = zoneId;

  option.addEventListener("click", onClick);
  optionsWrapper.appendChild(option);
}
