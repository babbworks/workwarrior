# jeremylongshore/waygate-mcp

**URL:** https://github.com/jeremylongshore/waygate-mcp  
**Stars:** 1  
**Language:** Python  
**Last push:** 2026-03-25  
**Archived:** No  
**Topics:** ai, api, automation, claude-code, claude-desktop, enterprise, file-management, grafana, mcp, model-context-protocol, monitoring, prometheus, python, security, taskwarrior  

## Description

Enterprise MCP server framework with secure file ops, command execution, and TaskWarrior integration. Zero-config security, Claude Desktop ready, comprehensive audit logging.

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 4  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: Python — tooling language used in ww

## README excerpt

```
# Waygate MCP - Complete Enterprise MCP Server Framework

[![Version](https://img.shields.io/badge/version-2.1.0-blue.svg)](https://github.com/waygateai/waygate-mcp/releases/tag/v2.1.0)
[![MCP Compatible](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.com)
[![Claude Desktop](https://img.shields.io/badge/Claude_Desktop-Ready-purple.svg)](https://claude.ai/desktop)
[![Security](https://img.shields.io/badge/Security-Hardened-red.svg)](#security-features)

🚀 **Production-Ready MCP Server**: Complete tool suite with enterprise security, TaskWarrior integration, and seamless Claude Desktop compatibility

## v2.1.0 "Complete Arsenal" Release (September 2025)

**🎉 MAJOR UPDATE**: Complete MCP tools implementation with zero-configuration security, automatic secret generation, and comprehensive Claude Desktop integration. **100% backward compatible** with enhanced reliability and production readiness.

## ✨ Complete Features

### 🛠️ MCP Tools Suite (NEW in v2.1.0)
✅ **execute_command**: Safe system command execution with timeout protection
✅ **read_file**: Secure file reading with path validation and size limits
✅ **write_file**: Protected file writing with content validation
✅ **list_directory**: Advanced directory listing with filtering
✅ **search_files**: Powerful content and filename search

### 🔒 Enterprise Security
✅ **Automatic Secret Generation**: Zero-configuration secure key management
✅ **Path Traversal Prevention**: All file operations restricted to safe directories
✅ **Command Injection Protection**: Dangerous commands blocked with validation
✅ **Zero-Trust Architecture**: All external requests proxied and audited
✅ **Container Isolation**: Read-only filesystem, non-root user, dropped capabilities

### 🖥️ Integration Ready
✅ **Claude Desktop Compatible**: Drop-in configuration with setup guide
✅ **MCP Protocol Compliant**: Full manifest with tool schemas
✅ **TaskWarrior Integration**: Professional project management system
✅ **Real-time Dashboard**: Live health monitoring and metrics

### 🏢 Production Features
✅ **Enterprise Monitoring**: Prometheus, Grafana, Elasticsearch stack
✅ **Auto-Start Service**: Systemd service for boot-time initialization
✅ **Graceful Fallbacks**: Continues operation when subsystems fail
✅ **Comprehensive Audit**: 7-year retention, complete request logging

## ⚡ 60-Second Quickstart

```bash
# Clone and start in 60 seconds
git clone https://github.com/waygateai/waygate-mcp.git && cd waygate-mcp
./quickstart.sh  # Automated setup + start
curl http://localhost:8000/health  # Verify running
```

That's it! Waygate MCP is running with all security features enabled.

## 🚀 Detailed Setup

### 1. Complete MCP Server (Recommended - v2.1.0)
```bash
git clone https://github.com/waygateai/waygate-mcp.git
cd waygate-mcp

# Setup virtual environment
python -m venv venv
source venv/bin/activate  # Linux/macOS
# venv\Scripts\activate    # Windows

# Install dependencies
pip install -r requireme
```