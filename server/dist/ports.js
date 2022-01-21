function setupPorts(app) {

    var stream = null,
        bindingWebcam = false,
        unbindRequested = false,
        recorder,
        pointerRecorder,
        pointerStream = null,
        pointer = { x: 0, y: 0, down: false },
        ctx = null,
        recording,
        currentEvents,
        nextSlideCallbacks = [],
        onbeforeunloadvalue = false,
        recordArrived = null,
        pointerArrived = null,
        pointerExists = false;


    window.addEventListener('beforeunload', function(event) {
        if (onbeforeunloadvalue) {
            event.preventDefault();
            event.returnValue = '';
        } else {
            delete event["returnValue"];
        }
    });

    var socket;
    if (flags.user) {
        initWebsocket();
    }

    function initWebsocket() {
        socket = new WebSocket(flags.global.socket_root);

        socket.onmessage = function(event) {
            console.log(event.data);
            app.ports.websocketMsg.send(JSON.parse(event.data));
        }

        socket.onopen = function() {
            socket.send(flags.user.cookie);
        }

        socket.onclose = function() {
            // Reconnect if connection is lost
            setTimeout(initWebsocket, 1000);
        }
    }

    function subscribe(object, fun) {
        if (object !== undefined) {
            object.subscribe(fun);
        }
    }

    function makeRequest(method, url, data, onprogress) {
        return new Promise(function (resolve, reject) {
            let xhr = new XMLHttpRequest();
            xhr.open(method, url, true);
            xhr.onload = function () {
                if (this.status >= 200 && this.status < 300) {
                    resolve(xhr);
                } else {
                    reject({
                        status: this.status,
                        statusText: xhr.statusText
                    });
                }
            };
            xhr.onerror = function () {
                reject({
                    status: this.status,
                    statusText: xhr.statusText
                });
            };
            if (typeof onprogress === 'function') {
                xhr.upload.onprogress = onprogress;
            }
            xhr.send(data);
        });
    }

    function setLanguage(arg) {
        localStorage.setItem('language', arg);
    }

    function setZoomLevel(arg) {
        localStorage.setItem('zoomLevel', arg);
    }

    function setAcquisitionInverted(arg) {
        localStorage.setItem('acquisitionInverted', arg);
    }

    function setVideoDeviceId(arg) {
        localStorage.setItem('videoDeviceId', arg);
    }

    function setResolution(arg) {
        localStorage.setItem('resolution', arg);
    }

    function setAudioDeviceId(arg) {
        localStorage.setItem('audioDeviceId', arg);
    }

    function setSortBy(arg) {
        localStorage.setItem('sortBy', JSON.stringify(arg));
    }

    function setPromptSize(arg) {
        localStorage.setItem('promptSize', arg);
    }

    function setOnBeforeUnloadValue(arg) {
        onbeforeunloadvalue = arg;
    }

    function refresh(canvas) {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        if (pointer.down) {
            pointerExists = true;
            let gradient = ctx.createRadialGradient(
                pointer.x, pointer.y, 3,
                pointer.x, pointer.y, 10
            );
            gradient.addColorStop(0, 'rgba(255, 0, 0, 1)');
            gradient.addColorStop(1, 'rgba(255, 0, 0, 0)');
            ctx.fillStyle = gradient;

            ctx.beginPath();
            ctx.arc(pointer.x, pointer.y, 20, 0, 2 * Math.PI);
            ctx.fill();
        }
    }

    function setupCanvasListeners() {
        let canvas = document.getElementById('pointer-canvas');
        canvas.width = 1920;
        canvas.height = 1080;
        ctx = canvas.getContext('2d');

        pointerStream = canvas.captureStream(30);

        canvas.addEventListener('mousedown', function(event) {
            pointer.down = true;
            pointer.x = event.offsetX * canvas.width / canvas.parentNode.clientWidth;
            pointer.y = event.offsetY * canvas.width / canvas.parentNode.clientWidth;
            refresh(canvas);
        });

        canvas.addEventListener('mouseup', function(event) {
            pointer.down = false;
            refresh(canvas);
        });

        canvas.addEventListener('moueout', function(event) {
            pointer.down = false;
            refresh(canvas);
        });

        canvas.addEventListener('mousemove', function(event) {
            pointer.x = event.offsetX * canvas.width / canvas.parentNode.clientWidth;
            pointer.y = event.offsetY * canvas.width / canvas.parentNode.clientWidth;
            refresh(canvas);
        });
    }

    async function findDevices(force) {

        let inputs = localStorage.getItem('devices');

        if (inputs !== null && !force) {
            console.log("Detecting devices from cache");
            app.ports.devicesReceived.send(JSON.parse(inputs));
            return;
        }

        console.log("Detecting devices");

        // Ask user media to ask permission so we can read labels later.
        try {
            console.log("a");
            stream = await navigator.mediaDevices.getUserMedia({video: true, audio: true});
            console.log("b");
        } catch (e) {
            try {
                stream = await navigator.mediaDevices.getUserMedia({video: false, audio: true});
            } catch(e) {
                app.ports.deviceDetectionFailed.send(null);
                return;
            }
        }

        await unbindWebcam();

        let devices = await navigator.mediaDevices.enumerateDevices();
        inputs = {
            video: [],
            audio: [],
        };

        for(let i = 0; i < devices.length; i ++) {
            let d = devices[i];
            if (d.kind === 'videoinput') {
                let device = {
                    deviceId: d.deviceId,
                    groupId: d.groupId,
                    label: d.label,
                    resolutions: [],
                };

                // Check all available resolutions for the video device.
                for (let res of quickScan) {
                    let options = {
                        audio: false,
                        video: {
                            deviceId: { exact: d.deviceId },
                            width: { exact: res.width },
                            height: { exact: res.height },
                        },
                    };

                    try {
                        stream = await navigator.mediaDevices.getUserMedia(options);
                        await unbindWebcam();
                        device.resolutions.push(res);
                    } catch (err) {
                        // Just don't add it
                    }

                }

                inputs.video.push(device);

            } else if (d.kind === 'audioinput') {
                inputs.audio.push(d);
            }
        };

        localStorage.setItem('devices', JSON.stringify(inputs));
        app.ports.devicesReceived.send(inputs);
    }

    async function bindWebcam(args) {
        let cameraOptions = args[0];
        let recorderOptions = args[1];

        if (unbindRequested) {
            unbindRequested = false;
        }

        if (bindingWebcam) {
            return;
        }

        // Unbound webcam before rebinding it.
        if (stream !== null) {
            await unbindWebcam();
        }

        console.log("Binding webcam");
        bindingWebcam = true;
        try {
            stream = await navigator.mediaDevices.getUserMedia(cameraOptions);
        } catch (e) {
            app.ports.bindingWebcamFailed.send(null);
            return;
        }

        if (unbindRequested) {
            await unbindWebcam();
        }

        await playWebcam();

        function sendRecordToElmIfReady() {
            if (recordArrived === null || pointerArrived === null) {
                return;
            }

            app.ports.recordArrived.send({
                webcam_blob: recordArrived,
                pointer_blob: pointerExists ? pointerArrived : null,
                events: currentEvents,
            });

            recordArrived = null;
            pointerArrived = null;
        }

        recorder = new MediaRecorder(stream, recorderOptions);
        recorder.ondataavailable = (data) => {
            recordArrived = data.data;
            sendRecordToElmIfReady();
        };

        recorder.onerror = (err) => {
            console.log(err);
        };

        setTimeout(() => {
            setupCanvasListeners();

            let pointerOptions = {
                videoBitsPerSecond : 2500000,
                mimeType : 'video/webm;codecs=vp8'
            };

            pointerRecorder = new MediaRecorder(pointerStream, pointerOptions);
            pointerRecorder.ondataavailable = (data) => {
                pointerArrived = data.data;
                sendRecordToElmIfReady();
            };

            pointerRecorder.onerror = (err) => {
                console.log(err);
            };
        }, 1000);

        bindingWebcam = false;

        console.log("Webcam bound");
        app.ports.webcamBound.send(null);
    }

    async function unbindWebcam() {
        if (stream === null || bindingWebcam) {
            unbindRequested = true;
            return
        }

        console.log("Unbinding webcam");
        stream.getTracks().forEach(function(track) {
            track.stop();
        });
        stream = null;
    }

    async function playWebcam() {
        if (stream === null) {
            return;
        }

        await new Promise(requestAnimationFrame);

        let element = document.getElementById(videoId);

        if (element == null) {
            return;
        }

        element.focus();
        element.srcObject = stream;
        element.src = null;
        element.muted = true;
        element.play();
    }

    async function playRecord(record) {
        let video = document.getElementById(videoId);
        video.srcObject = null;

        if (typeof record.webcam_blob === "string" || record.webcam_blob instanceof String) {
            video.src = record.webcam_blob;
        } else {
            video.src = URL.createObjectURL(record.webcam_blob);
        }

        video.muted = false;

        video.onended = () => {
            playWebcam();
            let extra = document.getElementById('extra');
            if (extra instanceof HTMLVideoElement) {
                extra.pause();
                extra.currentTime = 0;
            }
            app.ports.playRecordFinished.send(null);
        };

        // Skip last transition which is the end of the video.
        for (let i = 0; i < record.events.length - 1; i++) {
            let event = record.events[i];
            let callback;
            switch (event.ty) {
                case "next_slide":
                    callback = () => app.ports.nextSlideReceived.send(null);
                    break;

                case "play":
                    callback = () => {
                        let extra = document.getElementById('extra');
                        extra.muted = true;
                        extra.currentTime = 0;
                        extra.play();
                    };
                    break;

                case "stop":
                    callback = () => {
                        let extra = document.getElementById('extra');
                        extra.currentTime = 0;
                        extra.stop();
                    };
                    break;
            }

            if (callback !== undefined) {
                nextSlideCallbacks.push(setTimeout(callback, event.time));
            }
        }

        video.play();
    }

    function startRecording() {
        if (recorder !== undefined && !recording) {
            pointerExists = false;
            recording = true;
            recorder.start();
            pointerRecorder.start();
            currentEvents = [{
                time: Math.round(window.performance.now()),
                ty: "start"
            }];
            let extra = document.getElementById('extra');
            if (extra instanceof HTMLVideoElement) {
                extra.muted = true;
                extra.currentTime = 0;
                extra.play();
                currentEvents.push({
                    time: 0,
                    ty: "play"
                });
            }
        }
    }

    function stopRecording() {
        if (recording) {
            let time = Math.round(window.performance.now()) - currentEvents[0].time;

            let extra = document.getElementById('extra');
            if (extra instanceof HTMLVideoElement) {
                extra.muted = true;
                extra.pause();
                extra.currentTime = 0;
                currentEvents.push({
                    ty: "stop",
                    time: time
                });
            }

            currentEvents.push({
                time: time,
                ty: "end",
            });

            currentEvents[0].time = 0;
            recorder.stop();
            pointerRecorder.stop();
            recording = false;
        }
    }

    async function uploadRecord(args) {
        let capsuleId = args[0];
        let gos = args[1];
        let record = args[2];

        if (typeof record.webcam_blob === "string" || record.webmca_blob instanceof String) {

            // User wants to validate the old record, don't need to do anything,
            // just send the message to let them know it's done
            app.ports.capsuleUpdated.send(null);

        } else {

            try {
                let factor = record.pointer_blob === null ? 1 : 2;
                let xhr = await makeRequest("POST", "/api/upload-record/" + capsuleId + "/" + gos, record.webcam_blob, (e) => {
                    app.ports.progressReceived.send(e.loaded / (factor * e.total));
                });

                if (record.pointer_blob !== null) {
                    xhr = await makeRequest("POST", "/api/upload-pointer/" + capsuleId + "/" + gos, record.pointer_blob, (e) => {
                        app.ports.progressReceived.send(0.5 + e.loaded / e.total);
                    });
                }

                let capsule = JSON.parse(xhr.responseText);
                capsule.structure[gos].events = record.events;

                await makeRequest("POST", "/api/update-capsule/", JSON.stringify(capsule));

                app.ports.capsuleUpdated.send(capsule);
            } catch (e) {
                console.log(e)
                app.ports.uploadRecordFailed.send(null);
            }

        }

    }

    function askNextSlide() {
        currentEvents.push({
            time: Math.round(window.performance.now()) - currentEvents[0].time,
            ty: "next_slide"
        });
    }

    function askNextSentence() {
        currentEvents.push({
            time: Math.round(window.performance.now()) - currentEvents[0].time,
            ty: "next_sentence"
        });
    }

    async function exportCapsule(capsule) {
        let zip = new JSZip();

        for (let gosIndex = 0; gosIndex < capsule.structure.length; gosIndex++) {

            let gos = capsule.structure[gosIndex];
            let gosDir = zip.folder(gosIndex + 1);

            for (let slideIndex  = 0; slideIndex < gos.slides.length; slideIndex++) {
                let slide = gos.slides[slideIndex];

                let resp = await fetch("/data/" + capsule.id + "/assets/" + slide.uuid + ".png");
                let blob = await resp.blob();

                gosDir.file((slideIndex + 1) + ".png", blob);

                slide.uuid = (gosIndex + 1) + "/" + (slideIndex + 1) + ".png";

                if (slide.extra != undefined) {
                    let resp = await fetch("/data/" + capsule.id + "/assets/" + slide.extra + ".mp4");
                    let blob = await resp.blob();

                    gosDir.file((slideIndex + 1) + ".mp4", blob);
                    slide.extra = (gosIndex + 1) + "/" + (slideIndex + 1) + ".mp4";
                }


            }

            if (gos.record != undefined) {
                let resp = await fetch("/data/" + capsule.id + "/assets/" + gos.record.uuid + ".webm");
                let blob = await resp.blob();

                gosDir.file("record.webm", blob);
                gos.record = (gosIndex + 1) + "/record.webm";
            }

        }

        if (capsule.produced) {
            let resp = await fetch("/data/" + capsule.id + "/output.mp4");
            let blob = await resp.blob();
            zip.file("output.mp4", blob);
        }

        zip.file("structure.json", JSON.stringify(capsule, null, 4));

        let content = await zip.generateAsync({type: "blob"},
            function updateCallback(metadata) {
                console.log("progression: " + metadata.percent.toFixed(2) + " %");
                if(metadata.currentFile) {
                    console.log("current file = " + metadata.currentFile);
                }
            }
        );

        saveAs(content, capsule.id + ".zip");
    }

    async function importCapsule(args) {
        let project = args[0];
        let capsule = args[1];

        let zip = new JSZip();
        let content = await zip.loadAsync(capsule);
        console.log(content);
        let structure = JSON.parse(await content.file("structure.json").async("string"));

        // Creates the empty capsule.
        let resp = await fetch("/api/empty-capsule/" + project + "/" + structure.name + " (copie)", {method: "POST"});
        let json = await resp.json();

        structure.id = json.id;

        // Upload the slides.
        for (let gosIndex = 0; gosIndex < structure.structure.length; gosIndex++) {
            let gos = structure.structure[gosIndex];

            for (let slideIndex = 0; slideIndex < gos.slides.length; slideIndex++) {
                let slide = gos.slides[slideIndex];
                let image = await content.file(slide.uuid).async("blob");
                image = image.slice(0, image.size, "image/png")

                // Upload the slide.
                let resp = await fetch("/api/add-slide/" + json.id + "/-1/-1", {method: "POST", body: image});
                resp = await resp.json();

                // Find uuid of the slide we added.
                let newGos = resp.structure[resp.structure.length - 1];
                let newSlide = newGos.slides[newGos.slides.length - 1];

                slide.uuid = newSlide.uuid;
            }

        }

        // Set the correct structure.
        // Remove records because they are currently null.
        let structureClone = JSON.parse(JSON.stringify(structure));
        for (let gos of structureClone.structure) {
            gos.record = null;
            for (let slide of gos.slides) {
                slide.extra = null;
            }
        }

        // Remove from json attributes that the server doesn't want.
        delete structureClone.produced;

        await fetch("/api/update-capsule/", {
            method: "POST",
            body: JSON.stringify(structureClone),
            headers: {"Content-Type": "application/json"},
        });

        resp = undefined;

        // Upload the records and extra
        for (let gosIndex = 0; gosIndex < structure.structure.length; gosIndex++) {
            let gos = structure.structure[gosIndex];

            // Upload the gos record if any.
            if (gos.record !== null) {
                let blob = await content.file(gos.record).async("blob");
                blob = blob.slice(0, blob.size, "video/webm");
                resp = await fetch("/api/upload-record/" + json.id + "/" + gosIndex, {method: "POST", body: blob});
            }

            for (let slideIndex = 0; slideIndex < gos.slides.length; slideIndex++) {
                let slide = gos.slides[slideIndex];
                if (slide.extra !== null) {
                    let blob = await content.file(slide.extra).async("blob");
                    blob = blob.slice(0, blob.size, "video/mp4");
                    resp = await fetch("/api/replace-slide/" + json.id + "/" + slide.uuid + "/-1", {method: "POST", body: blob});

                }
            }
        }

        // let lastStructure = resp !== undefined ? await resp.json() : structureClone;
        // app.ports.capsuleUpdated.send(lastStructure);

    }

    function copyString(str) {
        let el = document.createElement('textarea');
        el.value = str;
        el.setAttribute('readonly', '');
        el.style = {position: 'absolute', left: '-9999px'};
        document.body.appendChild(el);
        el.select();
        document.execCommand('copy');
        document.body.removeChild(el);
    }

    function scrollIntoView(anchor) {
        let element = document.getElementById(anchor);
        if (element !== null) {
            element.scrollIntoView();
        }
    }

    function select(args) {
        let project = args[0];
        let mimes = args[1];
        let input = document.createElement('input');
        input.type = 'file';
        input.accept = mimes.join(',');
        input.onchange = function(e) {
            app.ports.selected.send([project, e.target.files[0]]);
        };
        input.click();
    }

    subscribe(app.ports.setLanguage, setLanguage);
    subscribe(app.ports.setZoomLevel, setZoomLevel);
    subscribe(app.ports.setAcquisitionInverted, setAcquisitionInverted);
    subscribe(app.ports.setVideoDeviceId, setVideoDeviceId);
    subscribe(app.ports.setResolution, setResolution);
    subscribe(app.ports.setAudioDeviceId, setAudioDeviceId);
    subscribe(app.ports.setSortBy, setSortBy);
    subscribe(app.ports.setPromptSize, setPromptSize);
    subscribe(app.ports.setOnBeforeUnloadValue, setOnBeforeUnloadValue);
    subscribe(app.ports.findDevices, findDevices);
    subscribe(app.ports.playWebcam, playWebcam);
    subscribe(app.ports.bindWebcam, bindWebcam);
    subscribe(app.ports.unbindWebcam, unbindWebcam);
    subscribe(app.ports.startRecording, startRecording);
    subscribe(app.ports.stopRecording, stopRecording);
    subscribe(app.ports.playRecord, playRecord);
    subscribe(app.ports.askNextSlide, askNextSlide);
    subscribe(app.ports.askNextSentence, askNextSentence);
    subscribe(app.ports.uploadRecord, uploadRecord);
    subscribe(app.ports.copyString, copyString);
    subscribe(app.ports.scrollIntoView, scrollIntoView);
    subscribe(app.ports.exportCapsule, exportCapsule);
    subscribe(app.ports.importCapsule, importCapsule);
    subscribe(app.ports.select, select);

    const quickScan = [
        { "width": 3840, "height": 2160 }, { "width": 1920, "height": 1080 }, { "width": 1600, "height": 1200 },
        { "width": 1280, "height":  720 }, { "width":  800, "height":  600 }, { "width":  640, "height":  480 },
        { "width":  640, "height":  360 }, { "width":  352, "height":  288 }, { "width":  320, "height":  240 },
        { "width":  176, "height":  144 }, { "width":  160, "height":  120 }
    ];

    const videoId = "video";
}
