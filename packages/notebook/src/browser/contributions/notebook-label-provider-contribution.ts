// *****************************************************************************
// Copyright (C) 2024 TypeFox and others.
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

import { LabelProvider, LabelProviderContribution } from '@theia/core/lib/browser';
import { inject, injectable } from '@theia/core/shared/inversify';
import { CellUri } from '../../common';
import { NotebookService } from '../service/notebook-service';
import type Token = require('markdown-it/lib/token');
import markdownit = require('@theia/core/shared/markdown-it');
import { NotebookCellModel } from '../view-model/notebook-cell-model';
import { URI } from '@theia/core';

@injectable()
export class NotebookLabelProviderContribution implements LabelProviderContribution {

    @inject(NotebookService)
    protected readonly notebookService: NotebookService;

    @inject(LabelProvider)
    protected readonly labelProvider: LabelProvider;

    protected markdownIt = markdownit();

    canHandle(element: object): number {
        return 0;
    }

    getIcon(): string {
        return '';
    }

    getName(): string {
        return '';
    }

    getLongName(): string {
        return '';
    }

    extractPlaintext(parsedMarkdown: Token[]): string {
        return parsedMarkdown.map(token => token.children ? this.extractPlaintext(token.children) : token.content).join('');
    }

    findCellByUri(uri: URI): NotebookCellModel | undefined {
        const parsed = CellUri.parse(uri);
        if (parsed) {
            return this.notebookService.getNotebookEditorModel(parsed.notebook)?.cells.find(cell => cell.handle === parsed?.handle);
        }
        return undefined;
    }

}
