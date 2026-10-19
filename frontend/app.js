function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { escapeHtml };
}

if (typeof document !== "undefined") {
  const globalScope = typeof window !== "undefined" ? window : globalThis;
  const API_URL = globalScope.API_URL || "http://localhost:8000";
  const NOTIFICATION_URL = globalScope.NOTIFICATION_URL || "http://localhost:8001";

  const form = document.getElementById("task-form");
  const tasksEl = document.getElementById("tasks");
  const notificationsEl = document.getElementById("notifications");
  const statusEl = document.getElementById("status");

  function setStatus(message) {
    if (statusEl) {
      statusEl.textContent = message;
    }
  }

  async function fetchJson(url, options = {}) {
    const response = await fetch(url, {
      headers: { "Content-Type": "application/json", ...(options.headers || {}) },
      ...options,
    });
    if (!response.ok) {
      const text = await response.text();
      throw new Error(text || `HTTP ${response.status}`);
    }
    if (response.status === 204) {
      return null;
    }
    return response.json();
  }

  function renderTasks(tasks) {
    if (!tasksEl) return;
    if (!tasks.length) {
      tasksEl.innerHTML = '<li class="empty">Поки немає завдань</li>';
      return;
    }

    tasksEl.innerHTML = tasks
      .map(
        (task) => `
        <li class="task ${task.completed ? "done" : ""}">
          <div>
            <p class="task-title">${escapeHtml(task.title)}</p>
            <p class="task-desc">${escapeHtml(task.description || "Без опису")}</p>
          </div>
          <div class="actions">
            <button type="button" data-action="toggle" data-id="${task.id}" data-completed="${task.completed}">
              ${task.completed ? "Відкрити" : "Завершити"}
            </button>
            <button type="button" class="danger" data-action="delete" data-id="${task.id}">Видалити</button>
          </div>
        </li>`
      )
      .join("");
  }

  function renderNotifications(items) {
    if (!notificationsEl) return;
    if (!items.length) {
      notificationsEl.innerHTML = '<li class="empty">Подій ще немає</li>';
      return;
    }

    notificationsEl.innerHTML = items
      .map(
        (item) => `
        <li class="task">
          <div>
            <p class="task-title">${escapeHtml(item.message)}</p>
            <p class="task-desc">source: ${escapeHtml(item.source)} · task_id: ${item.task_id ?? "—"}</p>
          </div>
        </li>`
      )
      .join("");
  }

  async function loadTasks() {
    const tasks = await fetchJson(`${API_URL}/tasks`);
    renderTasks(tasks);
  }

  async function loadNotifications() {
    const items = await fetchJson(`${NOTIFICATION_URL}/notifications`);
    renderNotifications(items);
  }

  async function refreshAll() {
    const results = await Promise.allSettled([loadTasks(), loadNotifications()]);
    const rejected = results.filter((r) => r.status === "rejected");
    if (rejected.length === results.length) {
      throw rejected[0].reason;
    }
  }

  if (form) {
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const title = document.getElementById("title").value.trim();
      const description = document.getElementById("description").value.trim();

      try {
        await fetchJson(`${API_URL}/tasks`, {
          method: "POST",
          body: JSON.stringify({ title, description }),
        });
        form.reset();
        setStatus("Завдання створено");
        await refreshAll();
      } catch (error) {
        setStatus(`Помилка: ${error.message}`);
      }
    });
  }

  if (tasksEl) {
    tasksEl.addEventListener("click", async (event) => {
      const button = event.target.closest("button[data-action]");
      if (!button) return;

      const id = button.dataset.id;
      const action = button.dataset.action;

      try {
        if (action === "toggle") {
          const completed = button.dataset.completed === "true";
          await fetchJson(`${API_URL}/tasks/${id}`, {
            method: "PATCH",
            body: JSON.stringify({ completed: !completed }),
          });
        }
        if (action === "delete") {
          await fetchJson(`${API_URL}/tasks/${id}`, { method: "DELETE" });
        }
        setStatus("Оновлено");
        await refreshAll();
      } catch (error) {
        setStatus(`Помилка: ${error.message}`);
      }
    });
  }

  const refreshTasksBtn = document.getElementById("refresh");
  if (refreshTasksBtn) {
    refreshTasksBtn.addEventListener("click", () => {
      loadTasks()
        .then(() => setStatus("Список завдань оновлено"))
        .catch((error) => setStatus(`Помилка: ${error.message}`));
    });
  }

  const refreshNotificationsBtn = document.getElementById("refresh-notifications");
  if (refreshNotificationsBtn) {
    refreshNotificationsBtn.addEventListener("click", () => {
      loadNotifications()
        .then(() => setStatus("Сповіщення оновлено"))
        .catch((error) => setStatus(`Помилка: ${error.message}`));
    });
  }

  refreshAll().catch((error) => setStatus(`Не вдалося підключитись: ${error.message}`));
}
