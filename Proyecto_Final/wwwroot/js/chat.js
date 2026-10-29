(function () {
    "use strict";

    document.addEventListener("DOMContentLoaded", function () {
        const privateButton = document.getElementById("btnPrivateChat");
        const departmentButton = document.getElementById("btnDepartmentChat");
        const chatWindow = document.getElementById("chatWindow");
        const closeButton = document.getElementById("closeChat");
        const token = document.querySelector("#chatAntiforgery input[name='__RequestVerificationToken']")?.value;

        if (!privateButton || !departmentButton || !chatWindow || !closeButton || !token || !window.signalR) {
            return;
        }

        const state = {
            mode: null,
            conversationId: null,
            departmentId: null,
            currentUserId: null,
            canPost: false,
            users: [],
            departments: [],
            peerName: "",
            messagePageSize: 50
        };

        document.body.appendChild(chatWindow);

        const connection = new signalR.HubConnectionBuilder()
            .withUrl("/chatHub")
            .withAutomaticReconnect([0, 2000, 5000, 10000])
            .build();

        connection.on("ReceiveMessage", function (message) {
            if (state.mode === "private" && Number(message.conversacionId) === Number(state.conversationId)) {
                appendMessage(message, Number(message.remitenteId) === Number(state.currentUserId));
            }
        });

        connection.on("ReceiveDepartmentMessage", function (message) {
            if (state.mode === "department" && Number(message.departamentoId) === Number(state.departmentId)) {
                appendMessage(message, Number(message.remitenteId) === Number(state.currentUserId), message.remitenteNombre);
            }
        });

        connection.onreconnected(joinCurrentResource);
        connection.onclose(function () {
            showNotice("Se perdió la conexión en tiempo real. Vuelva a abrir el chat.", "warning");
        });

        startConnection();

        privateButton.addEventListener("click", async function (event) {
            event.preventDefault();
            chatWindow.classList.add("show");
            await leaveCurrentResource();
            await showUsers();
        });

        departmentButton.addEventListener("click", async function (event) {
            event.preventDefault();
            chatWindow.classList.add("show");
            await leaveCurrentResource();
            await showDepartments();
        });

        closeButton.addEventListener("click", async function () {
            await leaveCurrentResource();
            chatWindow.classList.remove("show");
        });

        async function startConnection() {
            try {
                await connection.start();
            } catch (error) {
                console.error("No se pudo iniciar SignalR.", error);
                window.setTimeout(startConnection, 5000);
            }
        }

        async function showUsers() {
            state.mode = "users";
            setBodyList("Buscar usuario...", "Cargando usuarios...");
            try {
                const data = await requestJson("/Chat/GetUsers");
                state.users = data.users || [];
                renderUsers(state.users);
                bindFilter("chatListSearch", function (value) {
                    renderUsers(state.users.filter(function (user) {
                        return `${user.nombreCompleto} ${user.correo}`.toLowerCase().includes(value);
                    }));
                });
            } catch (error) {
                renderListError(error.message);
            }
        }

        function renderUsers(users) {
            const list = document.getElementById("chatSelectableList");
            if (!list) return;
            list.replaceChildren();
            if (!users.length) {
                list.appendChild(emptyState("No hay usuarios disponibles."));
                return;
            }
            users.forEach(function (user) {
                const button = document.createElement("button");
                button.type = "button";
                button.className = "chat-user-item";
                const name = document.createElement("strong");
                name.textContent = user.nombreCompleto || "Usuario";
                const email = document.createElement("small");
                email.textContent = user.correo || "";
                button.append(name, email);
                button.addEventListener("click", function () {
                    openConversation(user.usuarioId, user.nombreCompleto || "Conversación");
                });
                list.appendChild(button);
            });
        }

        async function openConversation(userId, name) {
            try {
                const data = await postForm("/Chat/OpenConversation", { userId: userId });
                await leaveCurrentResource();
                state.mode = "private";
                state.conversationId = data.conversationId;
                state.peerName = name;
                await ensureConnected();
                await connection.invoke("JoinConversation", Number(state.conversationId));
                renderConversation(name, true);
                await loadPrivateMessages();
            } catch (error) {
                showNotice(error.message, "danger");
            }
        }

        async function showDepartments() {
            state.mode = "departments";
            setBodyList("Buscar departamento...", "Cargando departamentos...");
            try {
                const data = await requestJson("/Chat/GetDepartments");
                state.departments = data.departments || [];
                renderDepartments(state.departments);
                bindFilter("chatListSearch", function (value) {
                    renderDepartments(state.departments.filter(function (department) {
                        return `${department.nombre} ${department.descripcion || ""}`.toLowerCase().includes(value);
                    }));
                });
            } catch (error) {
                renderListError(error.message);
            }
        }

        function renderDepartments(departments) {
            const list = document.getElementById("chatSelectableList");
            if (!list) return;
            list.replaceChildren();
            if (!departments.length) {
                list.appendChild(emptyState("No hay departamentos disponibles."));
                return;
            }
            departments.forEach(function (department) {
                const button = document.createElement("button");
                button.type = "button";
                button.className = "chat-user-item";
                const name = document.createElement("strong");
                name.textContent = department.nombre || "Departamento";
                const detail = document.createElement("small");
                detail.textContent = department.descripcion || `${department.totalUsuarios || 0} miembros`;
                button.append(name, detail);
                button.addEventListener("click", function () {
                    openDepartment(department);
                });
                list.appendChild(button);
            });
        }

        async function openDepartment(department) {
            try {
                await leaveCurrentResource();
                state.mode = "department";
                state.departmentId = department.departamentoId;
                state.canPost = Boolean(department.puedePublicar);
                await ensureConnected();
                await connection.invoke("JoinDepartment", Number(state.departmentId));
                renderConversation(department.nombre || "Departamento", state.canPost);
                await loadDepartmentMessages();
            } catch (error) {
                showNotice(error.message, "danger");
            }
        }

        function renderConversation(title, canPost) {
            const body = chatWindow.querySelector(".chat-body");
            body.replaceChildren();

            const toolbar = document.createElement("div");
            toolbar.className = "chat-conversation-header";
            const back = document.createElement("button");
            back.type = "button";
            back.className = "btn btn-link btn-sm";
            back.setAttribute("aria-label", "Volver");
            back.textContent = "←";
            back.addEventListener("click", async function () {
                const previousMode = state.mode;
                await leaveCurrentResource();
                if (previousMode === "private") await showUsers(); else await showDepartments();
            });
            const heading = document.createElement("strong");
            heading.textContent = title;
            const search = document.createElement("button");
            search.type = "button";
            search.className = "btn btn-link btn-sm ml-auto";
            search.textContent = "Buscar";
            search.addEventListener("click", showSearch);
            toolbar.append(back, heading, search);

            const messages = document.createElement("div");
            messages.id = "chatMessages";
            messages.className = "chat-messages";
            messages.appendChild(emptyState("Cargando mensajes..."));
            body.append(toolbar, messages);

            if (canPost) {
                const form = document.createElement("form");
                form.className = "chat-input-area";
                const input = document.createElement("textarea");
                input.id = "chatMessageInput";
                input.maxLength = 1000;
                input.rows = 2;
                input.required = true;
                input.placeholder = "Escriba un mensaje...";
                const send = document.createElement("button");
                send.type = "submit";
                send.className = "btn btn-primary btn-sm";
                send.textContent = "Enviar";
                form.append(input, send);
                form.addEventListener("submit", sendMessage);
                body.appendChild(form);
            } else {
                body.appendChild(emptyState("Este departamento es de solo lectura."));
            }
        }

        async function loadPrivateMessages(page = 1) {
            try {
                const data = await requestJson(`/Chat/GetMessages?conversationId=${encodeURIComponent(state.conversationId)}&page=${page}&pageSize=${state.messagePageSize}`);
                state.currentUserId = data.currentUserId;
                renderMessages(data.messages || [], false, page);
            } catch (error) {
                showNotice(error.message, "danger");
            }
        }

        async function loadDepartmentMessages(page = 1) {
            try {
                const data = await requestJson(`/Chat/GetDepartmentMessages?departmentId=${encodeURIComponent(state.departmentId)}&page=${page}&pageSize=${state.messagePageSize}`);
                state.currentUserId = data.currentUserId;
                renderMessages(data.messages || [], true, page);
            } catch (error) {
                showNotice(error.message, "danger");
            }
        }

        function renderMessages(messages, departmental, page) {
            const container = document.getElementById("chatMessages");
            if (!container) return;
            if (page === 1) container.replaceChildren();
            container.querySelector(".chat-load-older")?.remove();
            if (!messages.length && page === 1) {
                container.appendChild(emptyState("Todavía no hay mensajes."));
                return;
            }
            if (!messages.length) return;

            if (page === 1) {
                messages.forEach(function (message) {
                    appendMessage(message, Number(message.remitenteId) === Number(state.currentUserId), departmental ? message.remitenteNombre : null);
                });
                container.scrollTop = container.scrollHeight;
            } else {
                const previousHeight = container.scrollHeight;
                [...messages].reverse().forEach(function (message) {
                    const element = createMessageElement(
                        message,
                        Number(message.remitenteId) === Number(state.currentUserId),
                        departmental ? message.remitenteNombre : null);
                    if (element) container.prepend(element);
                });
                container.scrollTop = container.scrollHeight - previousHeight;
            }

            if (messages.length === state.messagePageSize) {
                const older = document.createElement("button");
                older.type = "button";
                older.className = "btn btn-link btn-sm chat-load-older";
                older.textContent = "Cargar mensajes anteriores";
                older.addEventListener("click", function () {
                    if (departmental) loadDepartmentMessages(page + 1); else loadPrivateMessages(page + 1);
                });
                container.prepend(older);
            }
        }

        function appendMessage(message, own, senderName) {
            const container = document.getElementById("chatMessages");
            if (!container || container.querySelector(`[data-message-id='${Number(message.mensajeId)}']`)) return;
            const initial = container.querySelector(".chat-loading");
            if (initial) initial.remove();
            const item = createMessageElement(message, own, senderName);
            if (!item) return;
            container.appendChild(item);
            container.scrollTop = container.scrollHeight;
        }

        function createMessageElement(message, own, senderName) {
            const container = document.getElementById("chatMessages");
            if (!container || container.querySelector(`[data-message-id='${Number(message.mensajeId)}']`)) return null;
            const item = document.createElement("article");
            item.className = own ? "chat-message sent" : "chat-message received";
            item.dataset.messageId = String(Number(message.mensajeId));
            if (senderName && !own) {
                const sender = document.createElement("strong");
                sender.textContent = senderName;
                item.appendChild(sender);
            }
            const content = document.createElement("p");
            content.textContent = message.contenido || "";
            const time = document.createElement("time");
            time.textContent = formatDate(message.fechaEnvio);
            item.append(content, time);
            return item;
        }

        async function sendMessage(event) {
            event.preventDefault();
            const input = document.getElementById("chatMessageInput");
            const content = input?.value.trim();
            if (!content) return;
            input.disabled = true;
            try {
                if (state.mode === "private") {
                    await postForm("/Chat/SendMessage", { conversationId: state.conversationId, content: content });
                } else {
                    await postForm("/Chat/SendDepartmentMessage", { departmentId: state.departmentId, content: content });
                }
                input.value = "";
            } catch (error) {
                showNotice(error.message, "danger");
            } finally {
                input.disabled = false;
                input.focus();
            }
        }

        function showSearch() {
            const previousMode = state.mode;
            const body = chatWindow.querySelector(".chat-body");
            body.replaceChildren();
            const form = document.createElement("form");
            form.className = "chat-search p-2";
            const input = document.createElement("input");
            input.type = "search";
            input.minLength = 2;
            input.maxLength = 100;
            input.required = true;
            input.placeholder = "Buscar en el historial autorizado...";
            const scope = document.createElement("select");
            scope.setAttribute("aria-label", "Alcance de la búsqueda");
            const currentOption = document.createElement("option");
            currentOption.value = "current";
            currentOption.textContent = "Conversación actual";
            const allOption = document.createElement("option");
            allOption.value = "all";
            allOption.textContent = "Todo mi historial";
            scope.append(currentOption, allOption);
            const submit = document.createElement("button");
            submit.type = "submit";
            submit.className = "btn btn-primary btn-sm";
            submit.textContent = "Buscar";
            const back = document.createElement("button");
            back.type = "button";
            back.className = "btn btn-link btn-sm";
            back.textContent = "Volver";
            back.addEventListener("click", function () {
                if (previousMode === "private") openConversationFromState(); else openDepartmentFromState();
            });
            form.append(input, scope, submit, back);
            const results = document.createElement("div");
            results.id = "chatSearchResults";
            results.className = "chat-users-list";
            body.append(form, results);
            form.addEventListener("submit", async function (event) {
                event.preventDefault();
                const query = input.value.trim();
                if (query.length < 2) return;
                await executeSearch(query, scope.value, previousMode, 1);
            });

            async function executeSearch(query, selectedScope, originMode, page) {
                try {
                    const request = { query: query, type: "all", page: page, pageSize: 25 };
                    if (selectedScope === "current" && originMode === "private") {
                        request.type = "private";
                        request.conversationId = state.conversationId;
                    }
                    if (selectedScope === "current" && originMode === "department") {
                        request.type = "department";
                        request.departmentId = state.departmentId;
                    }
                    const data = await postForm("/Chat/Search", request);
                    renderSearchResults(data.results || [], page > 1);
                    if (Number(data.total) > page * 25) {
                        const more = document.createElement("button");
                        more.type = "button";
                        more.className = "btn btn-link btn-sm chat-search-more";
                        more.textContent = "Cargar más resultados";
                        more.addEventListener("click", function () {
                            more.remove();
                            executeSearch(query, selectedScope, originMode, page + 1);
                        });
                        results.appendChild(more);
                    }
                } catch (error) {
                    showNotice(error.message, "danger");
                }
            }
        }

        function renderSearchResults(results, append) {
            const container = document.getElementById("chatSearchResults");
            if (!container) return;
            if (!append) container.replaceChildren();
            container.querySelector(".chat-search-more")?.remove();
            if (!results.length) {
                if (!append) container.appendChild(emptyState("No se encontraron coincidencias."));
                return;
            }
            results.forEach(function (result) {
                const article = document.createElement("button");
                article.type = "button";
                article.className = "chat-search-result text-left";
                const heading = document.createElement("strong");
                heading.textContent = `${result.senderName} · ${result.originName}`;
                const content = document.createElement("p");
                content.textContent = result.content;
                const date = document.createElement("time");
                date.textContent = formatDate(result.sentAt);
                article.append(heading, content, date);
                article.addEventListener("click", function () {
                    openSearchResult(result);
                });
                container.appendChild(article);
            });
        }

        async function openSearchResult(result) {
            if (result.originType === "privado" && result.conversationId) {
                await leaveCurrentResource();
                state.mode = "private";
                state.conversationId = result.conversationId;
                state.peerName = result.originName || "Conversación";
                await ensureConnected();
                await connection.invoke("JoinConversation", Number(state.conversationId));
                renderConversation(state.peerName, true);
                await loadPrivateMessages();
                return;
            }

            if (result.originType === "departamento" && result.departmentId) {
                if (!state.departments.some(item => Number(item.departamentoId) === Number(result.departmentId))) {
                    const data = await requestJson("/Chat/GetDepartments");
                    state.departments = data.departments || [];
                }
                const department = state.departments.find(item => Number(item.departamentoId) === Number(result.departmentId));
                if (department) await openDepartment(department);
            }
        }

        function openConversationFromState() {
            const id = state.conversationId;
            const name = state.peerName;
            state.mode = "private";
            state.conversationId = id;
            renderConversation(name, true);
            loadPrivateMessages();
        }

        function openDepartmentFromState() {
            const department = state.departments.find(item => Number(item.departamentoId) === Number(state.departmentId));
            state.mode = "department";
            renderConversation(department?.nombre || "Departamento", state.canPost);
            loadDepartmentMessages();
        }

        async function leaveCurrentResource() {
            if (connection.state === signalR.HubConnectionState.Connected) {
                try {
                    if (state.conversationId) await connection.invoke("LeaveConversation", Number(state.conversationId));
                    if (state.departmentId) await connection.invoke("LeaveDepartment", Number(state.departmentId));
                } catch (error) {
                    console.warn("No se pudo abandonar el grupo anterior.", error);
                }
            }
            state.conversationId = null;
            state.departmentId = null;
            state.canPost = false;
        }

        async function joinCurrentResource() {
            try {
                if (state.conversationId) await connection.invoke("JoinConversation", Number(state.conversationId));
                if (state.departmentId) await connection.invoke("JoinDepartment", Number(state.departmentId));
            } catch (error) {
                console.error("No se pudo restaurar el grupo autorizado.", error);
                showNotice("No fue posible restaurar el chat actual.", "warning");
            }
        }

        async function ensureConnected() {
            if (connection.state === signalR.HubConnectionState.Connected) return;
            if (connection.state === signalR.HubConnectionState.Disconnected) await connection.start();
        }

        function setBodyList(placeholder, loading) {
            const body = chatWindow.querySelector(".chat-body");
            body.replaceChildren();
            const search = document.createElement("div");
            search.className = "chat-search";
            const input = document.createElement("input");
            input.id = "chatListSearch";
            input.type = "search";
            input.autocomplete = "off";
            input.placeholder = placeholder;
            search.appendChild(input);
            const list = document.createElement("div");
            list.id = "chatSelectableList";
            list.className = "chat-users-list";
            list.appendChild(emptyState(loading));
            body.append(search, list);
        }

        function bindFilter(id, callback) {
            document.getElementById(id)?.addEventListener("input", function (event) {
                callback(event.target.value.trim().toLowerCase());
            });
        }

        function renderListError(message) {
            const list = document.getElementById("chatSelectableList");
            if (!list) return;
            list.replaceChildren(emptyState(message));
        }

        function emptyState(message) {
            const element = document.createElement("div");
            element.className = "chat-loading";
            element.textContent = message;
            return element;
        }

        function showNotice(message, kind) {
            const body = chatWindow.querySelector(".chat-body");
            if (!body) return;
            body.querySelector(".chat-inline-notice")?.remove();
            const notice = document.createElement("div");
            notice.className = `chat-inline-notice alert alert-${kind || "danger"}`;
            notice.setAttribute("role", "alert");
            notice.textContent = message || "No fue posible completar la operación.";
            body.prepend(notice);
        }

        async function requestJson(url, options) {
            const response = await fetch(url, Object.assign({
                credentials: "same-origin",
                headers: { "X-Requested-With": "XMLHttpRequest" }
            }, options || {}));
            const data = await response.json().catch(function () { return {}; });
            if (!response.ok || data.success === false) {
                throw new Error(data.message || "No fue posible completar la operación.");
            }
            return data;
        }

        function postForm(url, values) {
            const body = new URLSearchParams();
            Object.keys(values).forEach(function (key) {
                if (values[key] !== null && values[key] !== undefined) body.append(key, String(values[key]));
            });
            return requestJson(url, {
                method: "POST",
                headers: {
                    "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
                    "X-CSRF-TOKEN": token,
                    "X-Requested-With": "XMLHttpRequest"
                },
                body: body.toString()
            });
        }

        function formatDate(value) {
            const date = new Date(value);
            return Number.isNaN(date.getTime()) ? "" : date.toLocaleString("es-CR", { dateStyle: "short", timeStyle: "short" });
        }
    });
})();
