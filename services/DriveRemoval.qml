// SPDX-License-Identifier: Apache-2.0
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    // Jobs belong to the service, never to a dock tile or monitor. One job per
    // path also coalesces repeated clicks from different monitors.
    property var jobs: []
    property Component jobFactory: Component { DriveRemovalJob {} }

    function request(path, label) {
        if (!path) return;
        for (const job of jobs) {
            if (job.mountPath === path) { job.revealRequested(); return; }
        }
        const job = jobFactory.createObject(root, {mountPath: path, mountLabel: label});
        jobs = jobs.concat([job]);
        job.start();
    }

    function dismiss(job) {
        if (job.busy) return;
        if (jobs.indexOf(job) < 0) return;
        jobs = jobs.filter(other => other !== job);
        job.destroy();
    }
}
