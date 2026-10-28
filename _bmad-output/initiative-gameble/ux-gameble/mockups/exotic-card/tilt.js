/* Generated from app/frontend/lib/tilt.ts, glitter.ts and in_view.ts: the app's own tilt and glitter, attached to every face as tilt_controller.ts does. */
(function() {
	function motionReduced() {
		const forced = typeof document !== "undefined" ? document.documentElement.dataset.motion : void 0;
		if (forced === "reduced") return true;
		if (forced === "full") return false;
		return typeof window !== "undefined" && typeof window.matchMedia === "function" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
	}
	//#endregion
	//#region app/frontend/lib/tilt.ts
	var EASE_ENTER = .08;
	var EASE_LEAVE = .075;
	var TRAVEL = 2.5;
	var SNAP_DEGREES = .01;
	var CARD_ASPECT = 2 / 3;
	var REST = {
		rx: 0,
		ry: 0
	};
	var TILT_PROPERTIES = [
		"--tilt-rx",
		"--tilt-ry",
		"--reflection-strip",
		"--reflection-fresnel",
		"--reflection-horizon",
		"--reflection-hue"
	];
	var unit = (value) => Math.min(1, Math.max(0, value));
	var withoutNegativeZero = (value) => value + 0;
	function tiltTarget(x, y, rect, max) {
		const px = rect.width > 0 ? unit((x - rect.left) / rect.width) : .5;
		return {
			rx: withoutNegativeZero(-((rect.height > 0 ? unit((y - rect.top) / rect.height) : .5) - .5) * 2 * max),
			ry: withoutNegativeZero((px - .5) * 2 * max)
		};
	}
	function reflection(dx, dy, aspect) {
		const tilt2 = Math.min(1, (dx * dx + dy * dy) / .5);
		return {
			strip: withoutNegativeZero(30 - dx * TRAVEL * 55 - dy * TRAVEL * 30),
			fresnel: withoutNegativeZero(.8 + .6 * tilt2),
			horizon: withoutNegativeZero(-.32 - dy * TRAVEL - .2 * dx * TRAVEL * aspect),
			hue: withoutNegativeZero(50 + (dx * .6 + dy * .3) * TRAVEL * 120)
		};
	}
	reflection(0, 0, CARD_ASPECT);
	function leaning(tilt, max) {
		return {
			dx: withoutNegativeZero(tilt.ry / (2 * max)),
			dy: withoutNegativeZero(-tilt.rx / (2 * max))
		};
	}
	var settled = (a, b) => Math.abs(a.rx - b.rx) < SNAP_DEGREES && Math.abs(a.ry - b.ry) < SNAP_DEGREES;
	var atRest = (tilt) => settled(tilt, REST);
	function easeToward(current, target, factor) {
		const next = {
			rx: current.rx + (target.rx - current.rx) * factor,
			ry: current.ry + (target.ry - current.ry) * factor
		};
		return settled(next, target) ? { ...target } : next;
	}
	function layoutBox(element) {
		const rect = element.getBoundingClientRect();
		const width = element.offsetWidth || rect.width;
		const height = element.offsetHeight || rect.height;
		return {
			left: rect.left + rect.width / 2 - width / 2,
			top: rect.top + rect.height / 2 - height / 2,
			width,
			height
		};
	}
	function attachTilt(element, { max, onTilt }) {
		let current = REST;
		let target = REST;
		let frame = null;
		let driver = null;
		let hold = null;
		let box = null;
		let aspect = CARD_ASPECT;
		let swallowClick = false;
		const clear = () => {
			for (const property of TILT_PROPERTIES) element.style.removeProperty(property);
			delete element.dataset.tilt;
			delete element.dataset.tilting;
			onTilt?.(0, 0);
		};
		const write = () => {
			const { dx, dy } = leaning(current, max);
			const { strip, fresnel, horizon, hue } = reflection(dx, dy, aspect);
			element.style.setProperty("--tilt-rx", `${current.rx}deg`);
			element.style.setProperty("--tilt-ry", `${current.ry}deg`);
			element.style.setProperty("--reflection-strip", `${strip}%`);
			element.style.setProperty("--reflection-fresnel", `${fresnel}`);
			element.style.setProperty("--reflection-horizon", `${horizon}`);
			element.style.setProperty("--reflection-hue", `${hue}%`);
			onTilt?.(dx, dy);
		};
		const step = () => {
			frame = null;
			current = easeToward(current, target, driver === null ? EASE_LEAVE : EASE_ENTER);
			const still = settled(current, target);
			if (still && driver === null) {
				clear();
				return;
			}
			write();
			if (still && atRest(target)) delete element.dataset.tilt;
			else element.dataset.tilt = still ? "held" : "moving";
			if (!still) frame = requestAnimationFrame(step);
		};
		const schedule = () => {
			if (frame === null) frame = requestAnimationFrame(step);
		};
		const measure = () => {
			const measured = layoutBox(element);
			if (measured.width > 0 && measured.height > 0) aspect = measured.width / measured.height;
			return measured;
		};
		const aim = (x, y) => {
			box ??= measure();
			target = tiltTarget(x, y, box, max);
			schedule();
		};
		const drive = (id, touch) => {
			driver = {
				id,
				touch
			};
			element.dataset.tilting = "";
		};
		const release = () => {
			driver = null;
			box = null;
			delete element.dataset.tilting;
			target = REST;
			schedule();
		};
		const cancelHold = () => {
			if (hold) clearTimeout(hold.timer);
			hold = null;
		};
		const onPointerDown = (event) => {
			swallowClick = false;
			if (event.pointerType !== "touch" || driver !== null || hold !== null) return;
			const id = event.pointerId;
			const timer = setTimeout(() => {
				const held = hold;
				hold = null;
				if (!held || motionReduced()) return;
				drive(id, true);
				aim(held.x, held.y);
			}, 150);
			hold = {
				id,
				startX: event.clientX,
				startY: event.clientY,
				x: event.clientX,
				y: event.clientY,
				timer
			};
		};
		const onPointerMove = (event) => {
			if (event.pointerType === "touch") {
				if (hold?.id === event.pointerId) {
					if (Math.hypot(event.clientX - hold.startX, event.clientY - hold.startY) > 6) cancelHold();
					else Object.assign(hold, {
						x: event.clientX,
						y: event.clientY
					});
					return;
				}
			} else if (driver === null) {
				if (motionReduced()) return;
				drive(event.pointerId, false);
			}
			if (driver?.id === event.pointerId) aim(event.clientX, event.clientY);
		};
		const onPointerLeave = (event) => {
			if (event.pointerType !== "touch" && driver?.id === event.pointerId) release();
		};
		const onPointerEnd = (event) => {
			if (hold?.id === event.pointerId) cancelHold();
			if (driver?.id === event.pointerId && (driver.touch || event.type === "pointercancel")) {
				swallowClick = driver.touch && event.type === "pointerup";
				release();
			}
		};
		const onClick = (event) => {
			if (!swallowClick) return;
			swallowClick = false;
			event.preventDefault();
			event.stopPropagation();
		};
		const onTouchMove = (event) => {
			if (driver?.touch && event.cancelable) event.preventDefault();
		};
		const onContextMenu = (event) => {
			if (driver?.touch) event.preventDefault();
		};
		const onScroll = () => {
			box = null;
		};
		const view = element.ownerDocument?.defaultView;
		view?.addEventListener("scroll", onScroll, {
			capture: true,
			passive: true
		});
		element.addEventListener("pointerdown", onPointerDown);
		element.addEventListener("pointermove", onPointerMove);
		element.addEventListener("pointerleave", onPointerLeave);
		element.addEventListener("pointerup", onPointerEnd);
		element.addEventListener("pointercancel", onPointerEnd);
		element.addEventListener("touchmove", onTouchMove, { passive: false });
		element.addEventListener("click", onClick, { capture: true });
		element.addEventListener("contextmenu", onContextMenu);
		return () => {
			view?.removeEventListener("scroll", onScroll, { capture: true });
			element.removeEventListener("pointerdown", onPointerDown);
			element.removeEventListener("pointermove", onPointerMove);
			element.removeEventListener("pointerleave", onPointerLeave);
			element.removeEventListener("pointerup", onPointerEnd);
			element.removeEventListener("pointercancel", onPointerEnd);
			element.removeEventListener("touchmove", onTouchMove);
			element.removeEventListener("click", onClick, { capture: true });
			element.removeEventListener("contextmenu", onContextMenu);
			cancelHold();
			if (frame !== null) cancelAnimationFrame(frame);
			frame = null;
			driver = null;
			box = null;
			current = target = REST;
			clear();
		};
	}
	//#endregion
	//#region app/frontend/lib/glitter.ts
	var DEFAULT_SEED = 20261013;
	var FLASH_REACH = .14;
	var FLASH_THRESHOLD = .25;
	var REFERENCE_AREA = 6e4;
	var EDGE = 8;
	var ART_PIXEL = 2;
	var NORMAL_SPREAD = .9;
	var CROSS_SHARE = .35;
	var COLOURS = [
		"white",
		"white",
		"white",
		"gold",
		"gold",
		"violet",
		"blue"
	];
	function randomFrom(seed) {
		let state = seed | 0;
		return () => {
			state = state + 1831565813 | 0;
			let t = Math.imul(state ^ state >>> 15, 1 | state);
			t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
			return ((t ^ t >>> 14) >>> 0) / 4294967296;
		};
	}
	function glitterSeed(value) {
		const seed = Number.parseInt(value ?? "", 10);
		return Number.isNaN(seed) ? DEFAULT_SEED : seed;
	}
	var onPixelGrid = (value) => Math.round(value / ART_PIXEL) * ART_PIXEL;
	function flakeField(seed, width, height) {
		const random = randomFrom(seed);
		const groups = Array.from({ length: 3 }, () => ({
			period: 2.4 + random() * 3.6,
			delay: -random() * 6
		}));
		const count = Math.round(28 * width * height / REFERENCE_AREA);
		return {
			groups,
			flakes: Array.from({ length: count }, () => ({
				x: onPixelGrid(EDGE + random() * (width - 16)),
				y: onPixelGrid(EDGE + random() * (height - 16)),
				nx: (random() - .5) * NORMAL_SPREAD,
				ny: (random() - .5) * NORMAL_SPREAD,
				cross: random() < CROSS_SHARE,
				colour: COLOURS[Math.floor(random() * COLOURS.length)],
				group: Math.floor(random() * 3)
			}))
		};
	}
	function flakeFlash(flake, dx, dy) {
		return Math.max(0, 1 - Math.hypot(dx - flake.nx, dy - flake.ny) / FLASH_REACH) ** 1.5;
	}
	function flakeLevel(flash) {
		return .5 + .5 * Math.round(flash * 4) / 4;
	}
	function flakeElement(document, flake) {
		const element = document.createElement("span");
		element.className = `card__flake card__flake--${flake.colour}${flake.cross ? " card__flake--cross" : ""}`;
		element.style.setProperty("left", `${flake.x}px`);
		element.style.setProperty("top", `${flake.y}px`);
		const glint = document.createElement("span");
		glint.className = "card__flake-glint";
		element.append(glint);
		return element;
	}
	function groupElement(document, twinkle) {
		const element = document.createElement("span");
		element.className = "card__flake-group";
		element.style.setProperty("--flake-period", `${twinkle.period}s`);
		element.style.setProperty("--flake-delay", `${twinkle.delay}s`);
		return element;
	}
	function attachGlitter(container, { seed, width, height }) {
		const document = container.ownerDocument;
		const field = flakeField(seed, width, height);
		const groups = field.groups.map((twinkle) => groupElement(document, twinkle));
		const flakes = field.flakes.map((flake) => ({
			flake,
			element: flakeElement(document, flake),
			group: groups[flake.group],
			flashing: false,
			level: ""
		}));
		for (const { element, group } of flakes) group.append(element);
		container.replaceChildren(...groups);
		return {
			update(dx, dy) {
				for (const entry of flakes) {
					const flash = flakeFlash(entry.flake, dx, dy);
					const flashing = flash > FLASH_THRESHOLD;
					if (flashing !== entry.flashing) {
						entry.element.toggleAttribute("data-flash", flashing);
						(flashing ? container : entry.group).append(entry.element);
						entry.flashing = flashing;
					}
					const level = `${flakeLevel(flash)}`;
					if (level === entry.level) continue;
					entry.element.style.setProperty("--flake-level", level);
					entry.level = level;
				}
			},
			detach() {
				container.replaceChildren();
			}
		};
	}
	//#endregion
	//#region app/frontend/lib/in_view.ts
	var callbacks = /* @__PURE__ */ new Map();
	var observer = null;
	function observeInView(element, callback) {
		if (typeof IntersectionObserver === "undefined") {
			callback(true);
			return () => {};
		}
		observer ??= new IntersectionObserver((entries) => {
			for (const entry of entries) callbacks.get(entry.target)?.(entry.isIntersecting);
		});
		callbacks.set(element, callback);
		observer.observe(element);
		return () => {
			if (callbacks.get(element) !== callback) return;
			callbacks.delete(element);
			observer?.unobserve(element);
		};
	}
	//#endregion
	//#region ../../../../tmp/claude-1000/-home-teyermann-projets-gameble/b28e5aac-6c51-4661-97b0-79728ca67ca8/scratchpad/tiltbuild/entry.ts
	var pixels = (value) => {
		const trimmed = value.trim();
		return trimmed.endsWith("px") ? Number.parseFloat(trimmed) || 0 : void 0;
	};
	document.querySelectorAll(".card[data-tilt-max]").forEach((card) => {
		observeInView(card, (inView) => card.toggleAttribute("data-in-view", inView));
		const target = card.querySelector(".card__glitter");
		const style = getComputedStyle(card);
		const glitter = target ? attachGlitter(target, {
			seed: glitterSeed(target.dataset.glitterSeed),
			width: pixels(style.getPropertyValue("--card-width")) ?? card.offsetWidth,
			height: pixels(style.getPropertyValue("--card-height")) ?? card.offsetHeight
		}) : void 0;
		glitter?.update(0, 0);
		attachTilt(card, {
			max: Number(card.dataset.tiltMax) || 10,
			onTilt: glitter?.update
		});
	});
	//#endregion
})();
