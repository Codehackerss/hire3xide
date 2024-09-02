// *****************************************************************************
// Copyright (C) 2018 Red Hat, Inc. and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License v. 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// This Source Code may also be made available under the following Secondary
// Licenses when the conditions for such availability set forth in the Eclipse
// Public License v. 2.0 are satisfied: GNU General Public License, version 2
// with the GNU Classpath Exception which is available at
// https://www.gnu.org/software/classpath/license.html.
//
// SPDX-License-Identifier: EPL-2.0 OR GPL-2.0-only WITH Classpath-exception-2.0
// *****************************************************************************

import { injectable, inject, postConstruct } from '@theia/core/shared/inversify';
import URI from '@theia/core/lib/common/uri';
import { MessageService, Command, Emitter, Event } from '@theia/core/lib/common';
import { LabelProvider, isNative, AbstractDialog } from '@theia/core/lib/browser';
import { WindowService } from '@theia/core/lib/browser/window/window-service';
import { WorkspaceService } from '@theia/workspace/lib/browser';
import { FileDialogService } from '@theia/filesystem/lib/browser';
import { PluginDebugConfiguration, PluginDevServer } from '../common/plugin-dev-protocol';
import { HostedPluginPreferences } from './hosted-plugin-preferences';
import { FileService } from '@theia/filesystem/lib/browser/file-service';
import { EnvVariablesServer } from '@theia/core/lib/common/env-variables';
import { nls } from '@theia/core/lib/common/nls';

/**
 * Commands to control Hosted plugin instances.
 */
export namespace HostedPluginCommands {
    const HOSTED_PLUGIN_CATEGORY_KEY = 'theia/plugin-dev/hostedPlugin';
    const HOSTED_PLUGIN_CATEGORY = 'Hosted Plugin';
    export const START = Command.toLocalizedCommand({
        id: 'hosted-plugin:start',
        category: HOSTED_PLUGIN_CATEGORY,
        label: 'Start Instance'
    }, 'theia/plugin-dev/startInstance', HOSTED_PLUGIN_CATEGORY_KEY);
    export const STOP = Command.toLocalizedCommand({
        id: 'hosted-plugin:stop',
        category: HOSTED_PLUGIN_CATEGORY,
        label: 'Stop Instance'
    }, 'theia/plugin-dev/stopInstance', HOSTED_PLUGIN_CATEGORY_KEY);

    export const RESTART = Command.toLocalizedCommand({
        id: 'hosted-plugin:restart',
        category: HOSTED_PLUGIN_CATEGORY,
        label: 'Restart Instance'
    }, 'theia/plugin-dev/restartInstance', HOSTED_PLUGIN_CATEGORY_KEY);

    export const SELECT_PATH = Command.toLocalizedCommand({
        id: 'hosted-plugin:select-path',
        category: HOSTED_PLUGIN_CATEGORY,
        label: 'Select Path'
    }, 'theia/plugin-dev/selectPath', HOSTED_PLUGIN_CATEGORY_KEY);
}

/**
 * Available states of hosted plugin instance.
 */
export enum HostedInstanceState {
    STOPPED = 'stopped',
    STARTING = 'starting',
    RUNNING = 'running',
    STOPPING = 'stopping',
    FAILED = 'failed'
}

export interface HostedInstanceData {
    state: HostedInstanceState;
    pluginLocation: URI;
}

/**
 * Responsible for UI to set up and control Hosted Plugin Instance.
 */
@injectable()
export class HostedPluginManagerClient {
    private openNewTabAskDialog: OpenHostedInstanceLinkDialog;

    // path to the plugin on the file system
    protected pluginLocation: URI | undefined;

    // URL to the running plugin instance
    protected pluginInstanceURL: string | undefined;

    protected isDebug = false;

    protected readonly stateChanged = new Emitter<HostedInstanceData>();

    get onStateChanged(): Event<HostedInstanceData> {
        return this.stateChanged.event;
    }

    @inject(PluginDevServer)
    protected readonly hostedPluginServer: PluginDevServer;
    @inject(MessageService)
    protected readonly messageService: MessageService;
    @inject(LabelProvider)
    protected readonly labelProvider: LabelProvider;
    @inject(WindowService)
    protected readonly windowService: WindowService;
    @inject(FileService)
    protected readonly fileService: FileService;
    @inject(EnvVariablesServer)
    protected readonly environments: EnvVariablesServer;
    @inject(WorkspaceService)
    protected readonly workspaceService: WorkspaceService;
    @inject(HostedPluginPreferences)
    protected readonly hostedPluginPreferences: HostedPluginPreferences;
    @inject(FileDialogService)
    protected readonly fileDialogService: FileDialogService;

    @postConstruct()
    protected init(): void {
        this.doInit();
    }

    protected async doInit(): Promise<void> {
        this.openNewTabAskDialog = new OpenHostedInstanceLinkDialog(this.windowService);

        // is needed for case when page is loaded when hosted instance is already running.
        if (await this.hostedPluginServer.isHostedPluginInstanceRunning()) {
            this.pluginLocation = new URI(await this.hostedPluginServer.getHostedPluginURI());
        }
    }

    get lastPluginLocation(): string | undefined {
        if (this.pluginLocation) {
            return this.pluginLocation.toString();
        }
        return undefined;
    }

    async start(debugConfig?: PluginDebugConfiguration): Promise<void> {
        if (await this.hostedPluginServer.isHostedPluginInstanceRunning()) {
            this.messageService.warn(nls.localize('theia/plugin-dev/alreadyRunning', 'Hosted instance is already running.'));
            return;
        }

        if (!this.pluginLocation) {
            await this.selectPluginPath();
            if (!this.pluginLocation) {
                // selection was cancelled
                return;
            }
        }

        try {
            this.stateChanged.fire({ state: HostedInstanceState.STARTING, pluginLocation: this.pluginLocation });
            this.messageService.info(nls.localize('theia/plugin-dev/starting', 'Starting hosted instance server ...'));

            if (debugConfig) {
                this.isDebug = true;
                this.pluginInstanceURL = await this.hostedPluginServer.runDebugHostedPluginInstance(this.pluginLocation.toString(), debugConfig);
            } else {
                this.isDebug = false;
                this.pluginInstanceURL = await this.hostedPluginServer.runHostedPluginInstance(this.pluginLocation.toString());
            }
            await this.openPluginWindow();

            this.messageService.info(`${nls.localize('theia/plugin-dev/running', 'Hosted instance is running at:')} ${this.pluginInstanceURL}`);
            this.stateChanged.fire({ state: HostedInstanceState.RUNNING, pluginLocation: this.pluginLocation });
        } catch (error) {
            this.messageService.error(nls.localize('theia/plugin-dev/failed', 'Failed to run hosted plugin instance: {0}', this.getErrorMessage(error)));
            this.stateChanged.fire({ state: HostedInstanceState.FAILED, pluginLocation: this.pluginLocation });
            this.stop();
        }
    }
    async stop(checkRunning: boolean = true): Promise<void> {
        if (checkRunning && !await this.hostedPluginServer.isHostedPluginInstanceRunning()) {
            this.messageService.warn(nls.localize('theia/plugin-dev/notRunning', 'Hosted instance is not running.'));
            return;
        }
        try {
            this.stateChanged.fire({ state: HostedInstanceState.STOPPING, pluginLocation: this.pluginLocation! });
            await this.hostedPluginServer.terminateHostedPluginInstance();
            this.messageService.info((this.pluginInstanceURL
                ? nls.localize('theia/plugin-dev/instanceTerminated', '{0} has been terminated', this.pluginInstanceURL)
                : nls.localize('theia/plugin-dev/unknownTerminated', 'The instance has been terminated')));
            this.stateChanged.fire({ state: HostedInstanceState.STOPPED, pluginLocation: this.pluginLocation! });
        } catch (error) {
            this.messageService.error(this.getErrorMessage(error));
        }
    }

    async restart(): Promise<void> {
        if (await this.hostedPluginServer.isHostedPluginInstanceRunning()) {
            await this.stop(false);

            this.messageService.info(nls.localize('theia/plugin-dev/starting', 'Starting hosted instance server ...'));

            // It takes some time before OS released all resources e.g. port.
            // Keep trying to run hosted instance with delay.
            this.stateChanged.fire({ state: HostedInstanceState.STARTING, pluginLocation: this.pluginLocation! });
            let lastError;
            for (let tries = 0; tries < 15; tries++) {
                try {
                    if (this.isDebug) {
                        this.pluginInstanceURL = await this.hostedPluginServer.runDebugHostedPluginInstance(this.pluginLocation!.toString(), {
                            debugMode: this.hostedPluginPreferences['hosted-plugin.debugMode'],
                            debugPort: [...this.hostedPluginPreferences['hosted-plugin.debugPorts']]
                        });
                    } else {
                        this.pluginInstanceURL = await this.hostedPluginServer.runHostedPluginInstance(this.pluginLocation!.toString());
                    }
                    await this.openPluginWindow();
                    this.messageService.info(`${nls.localize('theia/plugin-dev/running', 'Hosted instance is running at:')} ${this.pluginInstanceURL}`);
                    this.stateChanged.fire({
                        state: HostedInstanceState.RUNNING,
                        pluginLocation: this.pluginLocation!
                    });
                    return;
                } catch (error) {
                    lastError = error;
                    await new Promise(resolve => setTimeout(resolve, 500));
                }
            }
            this.messageService.error(nls.localize('theia/plugin-dev/failed', 'Failed to run hosted plugin instance: {0}', this.getErrorMessage(lastError)));
            this.stateChanged.fire({ state: HostedInstanceState.FAILED, pluginLocation: this.pluginLocation! });
            this.stop();
        } else {
            this.messageService.warn(nls.localize('theia/plugin-dev/notRunning', 'Hosted instance is not running.'));
            this.start();
        }
    }

    /**
     * Creates directory choose dialog and set selected folder into pluginLocation field.
     */
    async selectPluginPath(): Promise<void> {
        const workspaceFolder = (await this.workspaceService.roots)[0] || await this.fileService.resolve(new URI(await this.environments.getHomeDirUri()));
        if (!workspaceFolder) {
            throw new Error('Unable to find the root');
        }

        const result = await this.fileDialogService.showOpenDialog({
            title: HostedPluginCommands.SELECT_PATH.label!,
            openLabel: nls.localize('theia/plugin-dev/select', 'Select'),
            canSelectFiles: false,
            canSelectFolders: true,
            canSelectMany: false
        }, workspaceFolder);

        if (result) {
            if (await this.hostedPluginServer.isPluginValid(result.toString())) {
                this.pluginLocation = result;
                this.messageService.info(nls.localize('theia/plugin-dev/pluginFolder', 'Plugin folder is set to: {0}', this.labelProvider.getLongName(result)));
            } else {
                this.messageService.error(nls.localize('theia/plugin-dev/noValidPlugin', 'Specified folder does not contain valid plugin.'));
            }
        }
    }

    /**
     * Opens window with URL to the running plugin instance.
     */
    protected async openPluginWindow(): Promise<void> {
        // do nothing for electron browser
        if (isNative) {
            return;
        }

        if (this.pluginInstanceURL) {
            try {
                this.windowService.openNewWindow(this.pluginInstanceURL);
            } catch (err) {
                // browser blocked opening of a new tab
                this.openNewTabAskDialog.showOpenNewTabAskDialog(this.pluginInstanceURL);
            }
        }
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    protected getErrorMessage(error: any): string {
        return error?.message?.substring(error.message.indexOf(':') + 1) || '';
    }
}

class OpenHostedInstanceLinkDialog extends AbstractDialog<string> {
    protected readonly windowService: WindowService;
    protected readonly openButton: HTMLButtonElement;
    protected readonly messageNode: HTMLDivElement;
    protected readonly linkNode: HTMLAnchorElement;
    value: string;

    constructor(windowService: WindowService) {
        super({
            title: nls.localize('theia/plugin-dev/preventedNewTab', 'Your browser prevented opening of a new tab')
        });
        this.windowService = windowService;

        this.linkNode = document.createElement('a');
        this.linkNode.target = '_blank';
        this.linkNode.setAttribute('style', 'color: var(--theia-editorWidget-foreground);');
        this.contentNode.appendChild(this.linkNode);

        const messageNode = document.createElement('div');
        messageNode.innerText = nls.localize('theia/plugin-dev/running', 'Hosted instance is running at:') + ' ';
        messageNode.appendChild(this.linkNode);
        this.contentNode.appendChild(messageNode);

        this.appendCloseButton();
        this.openButton = this.appendAcceptButton(nls.localizeByDefault('Open'));
    }

    showOpenNewTabAskDialog(uri: string): void {
        this.value = uri;

        this.linkNode.textContent = uri;
        this.linkNode.href = uri;
        this.openButton.onclick = () => {
            this.windowService.openNewWindow(uri);
        };

        this.open();
    }
}
