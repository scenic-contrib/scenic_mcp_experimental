#!/usr/bin/env node
/**
 * Apply Enhanced Tool Descriptions to Scenic MCP Server
 *
 * This script updates the MCP server with improved tool descriptions
 * designed to increase LLM discovery and usage rates.
 */
import * as fs from 'fs';
import * as path from 'path';
import { enhancedToolDescriptions } from './enhanced_tool_descriptions.js';
class DescriptionUpdater {
    sourceFile;
    backupFile;
    constructor() {
        this.sourceFile = path.join(__dirname, 'src', 'index.ts');
        this.backupFile = path.join(__dirname, 'src', 'index.ts.backup');
    }
    async updateDescriptions() {
        console.log('🔧 Updating Scenic MCP tool descriptions for better LLM usage\n');
        // Create backup
        await this.createBackup();
        // Read current file
        let content = fs.readFileSync(this.sourceFile, 'utf8');
        // Apply enhanced descriptions
        content = this.replaceToolDescriptions(content);
        // Write updated file
        fs.writeFileSync(this.sourceFile, content);
        console.log('✅ Enhanced descriptions applied successfully!');
        console.log(`📁 Backup saved as: ${this.backupFile}`);
        console.log('\n🧪 Next steps:');
        console.log('1. npm run build');
        console.log('2. Test with the LLM tool harness');
        console.log('3. Measure improvement in tool usage rates\n');
    }
    async createBackup() {
        if (fs.existsSync(this.sourceFile)) {
            fs.copyFileSync(this.sourceFile, this.backupFile);
            console.log('📋 Created backup of original file');
        }
    }
    replaceToolDescriptions(content) {
        console.log('🔄 Applying enhanced tool descriptions...\n');
        // Find the tools array in the ListToolsRequestSchema handler
        const toolsArrayStart = content.indexOf('tools: [');
        const toolsArrayEnd = content.indexOf('],', toolsArrayStart) + 1;
        if (toolsArrayStart === -1 || toolsArrayEnd === -1) {
            throw new Error('Could not find tools array in source file');
        }
        // Generate new tools array with enhanced descriptions
        const newToolsArray = this.generateEnhancedToolsArray();
        // Replace the tools array
        const before = content.substring(0, toolsArrayStart);
        const after = content.substring(toolsArrayEnd + 1);
        const updated = before + `tools: ${newToolsArray}` + after;
        // Log improvements
        enhancedToolDescriptions.forEach(tool => {
            console.log(`✨ Enhanced: ${tool.name}`);
            console.log(`   📝 Description: ${tool.description.substring(0, 80)}...`);
            console.log(`   🎯 Use cases: ${tool.useCases?.length || 0} defined`);
            console.log(`   📚 Examples: ${tool.examples?.length || 0} provided\n`);
        });
        return updated;
    }
    generateEnhancedToolsArray() {
        const tools = enhancedToolDescriptions.map(tool => {
            // Add usage guidance to description
            let fullDescription = tool.description;
            if (tool.useCases && tool.useCases.length > 0) {
                fullDescription += `\n\nCOMMON USE CASES: ${tool.useCases.join('; ')}`;
            }
            if (tool.examples && tool.examples.length > 0) {
                fullDescription += `\n\nEXAMPLES: ${tool.examples.join('; ')}`;
            }
            return {
                name: tool.name,
                description: fullDescription,
                inputSchema: tool.inputSchema
            };
        });
        return JSON.stringify(tools, null, 8).replace(/^/gm, '      ');
    }
    async revertChanges() {
        if (fs.existsSync(this.backupFile)) {
            fs.copyFileSync(this.backupFile, this.sourceFile);
            console.log('↩️ Reverted to original descriptions');
        }
        else {
            console.log('❌ No backup file found');
        }
    }
}
// CLI interface
async function main() {
    const args = process.argv.slice(2);
    const command = args[0] || 'update';
    const updater = new DescriptionUpdater();
    switch (command) {
        case 'update':
            await updater.updateDescriptions();
            break;
        case 'revert':
            await updater.revertChanges();
            break;
        default:
            console.log('Usage: node apply_enhanced_descriptions.js [update|revert]');
            console.log('  update - Apply enhanced descriptions (default)');
            console.log('  revert - Revert to original descriptions');
    }
}
if (import.meta.url === `file://${process.argv[1]}`) {
    main().catch(console.error);
}
//# sourceMappingURL=apply_enhanced_descriptions.js.map