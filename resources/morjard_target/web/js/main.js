import { createOptions } from "./createOptions.js";

const optionsWrapper = document.getElementById("options-wrapper");
const body = document.body;
const handIcon = document.querySelector("#hand i");

function forEachOption(list, fn) {
  if (Array.isArray(list)) {
    list.forEach((data, i) => data && fn(data, i + 1));
  } else if (list && typeof list === "object") {
    for (const key in list) {
      if (list[key]) fn(list[key], Number(key));
    }
  }
}

const savedTheme = localStorage.getItem("ox_target_theme");
if (savedTheme) {
  body.setAttribute("data-theme", savedTheme);
}

window.addEventListener("message", (event) => {
  switch (event.data.event) {
    case "visible": {
      optionsWrapper.innerHTML = "";
      body.style.visibility = event.data.state ? "visible" : "hidden";
      return handIcon.classList.remove("hand-hover");
    }

    case "leftTarget": {
      optionsWrapper.innerHTML = "";
      return handIcon.classList.remove("hand-hover");
    }

    case "setTarget": {
      optionsWrapper.innerHTML = "";
      handIcon.classList.add("hand-hover");

      if (event.data.options) {
        for (const type in event.data.options) {
          forEachOption(event.data.options[type], (data, id) => {
            createOptions(type, data, id);
          });
        }
      }

      if (event.data.zones) {
        forEachOption(event.data.zones, (zone, zoneId) => {
          forEachOption(zone, (data, id) => {
            createOptions("zones", data, id, zoneId);
          });
        });
      }
      break;
    }

    case "setTheme": {
      if (event.data.theme) {
        body.setAttribute("data-theme", event.data.theme);
        localStorage.setItem("ox_target_theme", event.data.theme);
      }
      break;
    }
  }
});
