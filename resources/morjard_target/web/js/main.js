import { createOptions } from "./createOptions.js";

const optionsWrapper = document.getElementById("options-wrapper");
const body = document.body;
const handIcon = document.querySelector("#hand i");

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
          event.data.options[type].forEach((data, id) => {
            createOptions(type, data, id + 1);
          });
        }
      }

      if (event.data.zones) {
        for (let i = 0; i < event.data.zones.length; i++) {
          event.data.zones[i].forEach((data, id) => {
            createOptions("zones", data, id + 1, i + 1);
          });
        }
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
