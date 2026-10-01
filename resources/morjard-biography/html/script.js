let currentLocale = 'en'
let locales = {}

async function loadLocale(lang) {
  if (locales[lang]) return locales[lang]
  try {
    const res = await fetch(`locales/${lang}.json`)
    const json = await res.json()
    locales[lang] = json
    return json
  } catch (e) {
    console.error('Failed to load locale', lang, e)
    return {}
  }
}

function t(key) {
  const l = locales[currentLocale] || {}
  return l[key] || key
}

window.addEventListener('message', (event) => {
  const d = event.data
  if (!d) return
  if (d.action === 'open') {
    populateUI(d.payload)
  } else if (d.action === 'hide') {
    const app = document.getElementById('app')
    if (app) app.style.display = 'none'
  }
})

function populateUI(payload) {
  const app = document.getElementById('app')
  if (app) app.style.display = 'block'

  const msgEl = document.getElementById('message')
  const bioEl = document.getElementById('bio')
  if (!payload.success) {
    msgEl.innerText = t(payload.message || 'no_data')
    msgEl.style.display = 'block'
    bioEl.style.display = 'none'
    return
  }
  msgEl.style.display = 'none'
  bioEl.style.display = 'block'
  document.getElementById('nameVal').innerText = payload.data.firstname || ''
  document.getElementById('surnameVal').innerText = payload.data.lastname || ''

  const totalMin = payload.data.total_minutes || 0
  const hours = Math.floor(totalMin / 60)
  document.getElementById('totalHoursVal').innerText = `${hours} h (${totalMin} min)`
  document.getElementById('totalDaysVal').innerText = `${Math.floor(hours / 24)} d`

  const jobsList = document.getElementById('jobsList')
  jobsList.innerHTML = ''
  const jobs = payload.data.jobs || {}
  for (const job in jobs) {
    const min = jobs[job]
    const hh = Math.floor(min / 60)
    const li = document.createElement('li')
    li.innerText = `${job}: ${hh} h (${min} min)`
    jobsList.appendChild(li)
  }

  const historyList = document.getElementById('historyList')
  historyList.innerHTML = ''
  const history = payload.data.job_history || []
  // aggregate minutes per job so UI shows one line per job with total hours
  const agg = {}
  for (const item of history) {
    const job = item.job || 'unknown'
    const mins = Number(item.minutes_added) || 0
    agg[job] = (agg[job] || 0) + mins
  }
  // display aggregated
  for (const job in agg) {
    const mins = agg[job]
    const hrs = Math.floor(mins / 60)
    const li = document.createElement('li')
    li.innerText = `${job}: ${hrs} h (${mins} min)`
    historyList.appendChild(li)
  }
}

// init controls
async function init() {
  const langSelect = document.getElementById('langSelect')
  const langs = ['en','cs','it','es']
  for (const l of langs) {
    const opt = document.createElement('option')
    opt.value = l
    opt.innerText = l.toUpperCase()
    langSelect.appendChild(opt)
  }
  langSelect.value = currentLocale
  await loadLocale(currentLocale)
  applyTexts()
  langSelect.addEventListener('change', async (e) => {
    currentLocale = e.target.value
    await loadLocale(currentLocale)
    applyTexts()
  })

  document.getElementById('closeBtn').addEventListener('click', () => {
    const app = document.getElementById('app')
    if (app) app.style.display = 'none'
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({}) })
  })
  document.getElementById('viewBtn').addEventListener('click', () => {
    const id = document.getElementById('playerIdInput').value
    fetch(`https://${GetParentResourceName()}/requestBiography`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ target: id }) })
  })
}

function applyTexts() {
  document.getElementById('title').innerText = t('Biography')
  document.getElementById('nameLabel').innerText = t('Name') + ':'
  document.getElementById('surnameLabel').innerText = t('Surname') + ':'
  document.getElementById('totalHoursLabel').innerText = t('Total Hours') + ':'
  document.getElementById('totalDaysLabel').innerText = t('Total Days') + ':'
  document.getElementById('jobsTitle').innerText = t('Jobs')
  document.getElementById('historyTitle').innerText = t('Job History')
  document.getElementById('closeBtn').innerText = t('Close')
  document.getElementById('viewByIdLabel').innerText = t('View by server id:')
  document.getElementById('viewBtn').innerText = t('View')
}

init()