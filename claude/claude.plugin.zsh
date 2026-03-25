# Claude Code Zsh autocompletion plugin
# Supports intelligent completion for claude-code commands, including subcommands and parameters

# Main completion function
_claude_code() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    local -a commands claude_opts

    # Define main commands (based on claude --help)
    commands=(
        'agents:List configured agents'
        'auth:Manage authentication'
        'doctor:Check health of Claude Code auto-updater'
        'install:Install Claude Code native version'
        'mcp:Configure and manage MCP servers'
        'plugin:Manage Claude Code plugins'
        'setup-token:Set up long-term authentication token'
        'update|upgrade:Check and install available updates'
        'help:Display help information'
    )

    # Claude Code common options (based on actual command-line arguments)
    claude_opts=(
        '--model:Specify model (sonnet, opus, haiku or full model name)'
        '--agent:Agent for current session'
        '--fallback-model:Enable automatic fallback model'
        '--system-prompt:System prompt'
        '--append-system-prompt:Append system prompt'
        '--permission-mode:Permission mode (acceptEdits, bypassPermissions, default, dontAsk, plan)'
        '--betas:Beta headers for API requests'
        '--chrome:Enable Claude in Chrome integration'
        '--no-chrome:Disable Claude in Chrome integration'
        '-c:Continue most recent conversation'
        '--continue:Continue most recent conversation'
        '--from-pr:Resume a session linked to a PR'
        '-r:Resume session'
        '--resume:Resume session (optional sessionId)'
        '--fork-session:Create new session ID when resuming'
        '--session-id:Use specific session ID (must be valid UUID)'
        '-p:Print response and exit'
        '--print:Print response and exit (for piping)'
        '--max-budget-usd:Maximum API budget in USD'
        '--output-format:Output format (text, json, stream-json)'
        '--input-format:Input format (text, stream-json)'
        '--include-partial-messages:Include partial message blocks'
        '--no-session-persistence:Disable session persistence in print mode'
        '--replay-user-messages:Replay user messages'
        '--tools:Specify available tool list'
        '--allowedTools:Allowed tool list (camelCase alias)'
        '--allowed:Allowed tool list'
        '--allowed-tools:Allowed tool list'
        '--disallowedTools:Disallowed tool list (camelCase alias)'
        '--disallowed:Disallowed tool list'
        '--disallowed-tools:Disallowed tool list'
        '--disable-slash-commands:Disable all skills'
        '--mcp-config:Load MCP servers from JSON file or string'
        '--mcp-debug:Enable MCP debug mode'
        '--strict-mcp-config:Use only MCP servers from --mcp-config'
        '--dangerously-skip-permissions:Bypass all permission checks'
        '--allow-dangerously-skip-permissions:Allow bypass permission check option'
        '--file:Download file resource at startup'
        '--settings:Load settings from JSON file or string'
        '--setting-sources:Setting source list (user, project, local)'
        '--effort:Effort level (low, medium, high)'
        '--add-dir:Additional directories for tool access'
        '--plugin-dir:Directory to load plugins for this session'
        '--agents:JSON object for custom agents'
        '--ide:Automatically connect to IDE on startup'
        '--json-schema:JSON schema file or string'
        '--tmux:Create tmux session for worktree'
        '-w:Create worktree for this session'
        '--worktree:Create worktree for this session'
        '-d:Enable debug mode'
        '--debug:Enable debug mode (optional category filter)'
        '--debug-file:Write debug logs to file'
        '-e:Extra parameters'
        '-i:Input related options'
        '-j:JSON related options'
        '-o:Output related options'
        '-s:Settings related options'
        '--verbose:Override verbose mode setting in config'
        '-v:Show version number'
        '--version:Show version number'
        '-h:Show help'
        '--help:Show help'
    )

    _arguments -C \
        '(- *)'{-h,--help}'[Show help]' \
        '(- *)'{-v,--version}'[Show version number]' \
        '--model[Specify model]' \
        '--agent[Agent for current session]:agent:' \
        '--fallback-model[Enable automatic fallback model]' \
        '--system-prompt[System prompt]' \
        '--append-system-prompt[Append system prompt]' \
        '--permission-mode[Permission mode]:mode:(acceptEdits bypassPermissions default dontAsk plan)' \
        '--betas[Beta headers for API requests]:beta headers:' \
        '--chrome[Enable Claude in Chrome integration]' \
        '--no-chrome[Disable Claude in Chrome integration]' \
        {-c,--continue}'[Continue most recent conversation]' \
        '--from-pr[Resume a session linked to a PR]:pr_or_url:' \
        {-r,--resume}'[Resume session]:session_id:' \
        '--fork-session[Create new session ID when resuming]' \
        '--session-id[Use specific session ID]:uuid:' \
        {-p,--print}'[Print response and exit]' \
        '--max-budget-usd[Maximum API budget in USD]:amount:' \
        '--output-format[Output format]:format:(text json stream-json)' \
        '--input-format[Input format]:format:(text stream-json)' \
        '--include-partial-messages[Include partial message blocks]' \
        '--no-session-persistence[Disable session persistence in print mode]' \
        '--replay-user-messages[Replay user messages]' \
        '--tools[Specify available tool list]:tools:' \
        '--allowedTools[Allowed tool list]:tools:' \
        '--allowed[Allowed tool list]:tools:' \
        '--allowed-tools[Allowed tool list]:tools:' \
        '--disallowedTools[Disallowed tool list]:tools:' \
        '--disallowed[Disallowed tool list]:tools:' \
        '--disallowed-tools[Disallowed tool list]:tools:' \
        '--disable-slash-commands[Disable all skills]' \
        '--mcp-config[Load MCP servers from JSON file or string]:config:_files' \
        '--mcp-debug[Enable MCP debug mode]' \
        '--strict-mcp-config[Use only MCP servers from --mcp-config]' \
        '--dangerously-skip-permissions[Bypass all permission checks]' \
        '--allow-dangerously-skip-permissions[Allow bypass permission check option]' \
        '--file[File resources to download]:file_specs:' \
        '--settings[Load settings from JSON file or string]:settings:_files' \
        '--setting-sources[Setting source list]:sources:(user project local)' \
        '--effort[Effort level]:level:(low medium high)' \
        '--add-dir[Additional directories for tool access]:directory:_files -/' \
        '--plugin-dir[Directory to load plugins for this session]:directory:_files -/' \
        '--agents[JSON object for custom agents]:json:' \
        '--ide[Automatically connect to IDE on startup]' \
        '--json-schema[JSON schema file or string]:schema:_files' \
        '--tmux[Create tmux session for worktree]' \
        {-w,--worktree}'[Create a new git worktree]:name:' \
        {-d,--debug}'[Enable debug mode]:category:' \
        '--debug-file[Write debug logs to file]:path:_files' \
        '-e[Extra parameters]:param:' \
        '-i[Input related options]:param:' \
        '-j[JSON related options]:param:' \
        '-o[Output related options]:param:' \
        '-s[Settings related options]:param:' \
        '--verbose[Override verbose mode setting in config]' \
        '1: :->command' \
        '*::arg:->args'

    case $state in
        command)
            _describe -t commands 'claude-code commands' commands
            ;;
        args)
            case $line[1] in
                agents)
                    _claude_code_agents
                    ;;
                auth)
                    _claude_code_auth
                    ;;
                plugin)
                    _claude_code_plugin
                    ;;
                mcp)
                    _claude_code_mcp
                    ;;
                doctor)
                    _claude_code_doctor
                    ;;
                install)
                    _claude_code_install
                    ;;
                setup-token)
                    _claude_code_setup_token
                    ;;
                update|upgrade)
                    _claude_code_update
                    ;;
                *)
                    _describe -t claude_opts 'claude-code options' claude_opts
                    _files
                    ;;
            esac
            ;;
    esac
}

# agents subcommand completion
_claude_code_agents() {
    _arguments \
        {-h,--help}'[Show help]' \
        '--setting-sources[Setting sources]:sources:(user project local)'
}

# auth subcommand completion
_claude_code_auth() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        {-h,--help}'[Show help]' \
        '1: :->command' \
        '*::arg:->args'

    case $state in
        command)
            local -a auth_cmds
            auth_cmds=(
                'login:Sign in to Anthropic account'
                'logout:Log out from Anthropic account'
                'status:Show authentication status'
            )
            _describe -t auth_cmds 'auth commands' auth_cmds
            ;;
        args)
            case $line[1] in
                login)
                    _claude_code_auth_login
                    ;;
                logout)
                    _claude_code_auth_logout
                    ;;
                status)
                    _claude_code_auth_status
                    ;;
            esac
            ;;
    esac
}

_claude_code_auth_login() {
    _arguments \
        '--email[Pre-populate email]:email:' \
        '--sso[Force SSO login flow]' \
        {-h,--help}'[Show help]'
}

_claude_code_auth_logout() {
    _arguments \
        {-h,--help}'[Show help]'
}

_claude_code_auth_status() {
    _arguments \
        '--json[Output as JSON]' \
        '--text[Output as human-readable text]' \
        {-h,--help}'[Show help]'
}

# plugin subcommand completion
_claude_code_plugin() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        {-h,--help}'[Show help]' \
        '1: :->command' \
        '*::arg:->args'

    case $state in
        command)
            local -a plugin_cmds
            plugin_cmds=(
                'install|i:Install plugin'
                'uninstall|remove:Uninstall plugin'
                'list:List installed plugins'
                'update:Update a plugin to latest version'
                'validate:Validate plugin or marketplace manifest'
                'marketplace:Manage Claude Code marketplace'
                'enable:Enable disabled plugin'
                'disable:Disable enabled plugin'
            )
            _describe -t plugin_cmds 'plugin commands' plugin_cmds
            ;;
        args)
            case $line[1] in
                marketplace)
                    _claude_code_plugin_marketplace
                    ;;
                install|i)
                    _arguments \
                        {-h,--help}'[Show help]' \
                        {-s,--scope}'[Installation scope]:scope:(user project local)' \
                        '*:plugin:'
                    ;;
                uninstall|remove)
                    _arguments \
                        {-h,--help}'[Show help]' \
                        {-s,--scope}'[Uninstall scope]:scope:(user project local)' \
                        '*:plugin:'
                    ;;
                disable)
                    _arguments \
                        {-a,--all}'[Disable all enabled plugins]' \
                        {-h,--help}'[Show help]' \
                        {-s,--scope}'[Installation scope]:scope:(user project local)'
                    ;;
                enable)
                    _arguments \
                        {-h,--help}'[Show help]' \
                        {-s,--scope}'[Installation scope]:scope:(user project local)'
                    ;;
                list)
                    _arguments \
                        '--available[Include available plugins from marketplaces (requires --json)]' \
                        '--json[Output as JSON]' \
                        {-h,--help}'[Show help]'
                    ;;
                update)
                    _arguments \
                        {-h,--help}'[Show help]' \
                        {-s,--scope}'[Installation scope]:scope:(user project local managed)' \
                        '*:plugin:'
                    ;;
                validate)
                    _arguments \
                        {-h,--help}'[Show help]' \
                        '*:file:_files'
                    ;;
            esac
            ;;
    esac
}

# plugin marketplace subcommand completion
_claude_code_plugin_marketplace() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        {-h,--help}'[Show help]' \
        '1: :->command' \
        '*::arg:->args'

    case $state in
        command)
            local -a plugin_marketplace_cmds
            plugin_marketplace_cmds=(
                'add:Add marketplace from URL, path or GitHub repository'
                'list:List all configured marketplaces'
                'remove|rm:Remove marketplace'
                'update:Update marketplace from source'
            )
            _describe -t plugin_marketplace_cmds 'marketplace commands' plugin_marketplace_cmds
            ;;
        args)
            case $line[1] in
                add)
                    _arguments \
                        {-h,--help}'[Show help]' \
                        '--scope[Marketplace declaration scope]:scope:(user project local)' \
                        '--sparse[Limit checkout to sparse paths]:path:' \
                        '*:source:'
                    ;;
                list)
                    _arguments \
                        '--json[Output as JSON]' \
                        {-h,--help}'[Show help]'
                    ;;
                remove|rm)
                    _arguments \
                        {-h,--help}'[Show help]' \
                        '*:marketplace:'
                    ;;
                update)
                    _arguments \
                        {-h,--help}'[Show help]' \
                        '*:marketplace:'
                    ;;
            esac
            ;;
    esac
}

# mcp subcommand completion
_claude_code_mcp() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        {-h,--help}'[Show help]' \
        '1: :->command' \
        '*::arg:->args'

    case $state in
        command)
            local -a mcp_cmds
            mcp_cmds=(
                'serve:Start Claude Code MCP server'
                'add:Add MCP server to Claude Code'
                'remove:Remove MCP server'
                'list:List configured MCP servers'
                'get:Get MCP server details'
                'add-json:Add MCP server using JSON string'
                'add-from-claude-desktop:Import MCP servers from Claude Desktop'
                'reset-project-choices:Reset all approved and rejected servers in project scope'
            )
            _describe -t mcp_cmds 'mcp commands' mcp_cmds
            ;;
        args)
            case $line[1] in
                add)
                    _arguments \
                        '--callback-port[Fixed OAuth callback port]:port:' \
                        '--client-id[OAuth client ID]:client_id:' \
                        '--client-secret[Prompt for OAuth client secret]' \
                        {-s,--scope}'[Configuration scope]:scope:(local user project)' \
                        {-t,--transport}'[Transport type]:transport:(stdio sse http)' \
                        {-e,--env}'[Set environment variable]:env:' \
                        {-H,--header}'[Set WebSocket headers]:header:' \
                        {-h,--help}'[Show help]' \
                        '*:file:_files'
                    ;;
                serve)
                    _arguments \
                        {-d,--debug}'[Enable debug mode]' \
                        '--verbose[Enable verbose output]' \
                        {-h,--help}'[Show help]'
                    ;;
                add-json)
                    _arguments \
                        '--client-secret[Prompt for OAuth client secret]' \
                        {-s,--scope}'[Configuration scope]:scope:(local user project)' \
                        {-h,--help}'[Show help]' \
                        '*:file:_files'
                    ;;
                add-from-claude-desktop)
                    _arguments \
                        {-s,--scope}'[Configuration scope]:scope:(local user project)' \
                        {-h,--help}'[Show help]'
                    ;;
                get)
                    _arguments \
                        {-h,--help}'[Show help]' \
                        '*::server:( $(claude mcp list 2>/dev/null | grep -E "^\s+\w+" | awk "{print \$1}") )'
                    ;;
                list)
                    _arguments \
                        {-h,--help}'[Show help]'
                    ;;
                remove)
                    _arguments \
                        {-s,--scope}'[Configuration scope]:scope:(local user project)' \
                        {-h,--help}'[Show help]' \
                        '*::server:( $(claude mcp list 2>/dev/null | grep -E "^\s+\w+" | awk "{print \$1}") )'
                    ;;
                reset-project-choices)
                    _arguments \
                        {-h,--help}'[Show help]'
                    ;;
            esac
            ;;
    esac
}

# doctor subcommand completion
_claude_code_doctor() {
    _arguments \
        {-h,--help}'[Show help]'
}

# install subcommand completion
_claude_code_install() {
    _arguments \
        '--force[Force reinstallation]' \
        {-h,--help}'[Show help]'
}

# migrate-installer subcommand completion
_claude_code_migrate_installer() {
    _arguments \
        {-h,--help}'[Show help]'
}

# setup-token subcommand completion
_claude_code_setup_token() {
    _arguments \
        {-h,--help}'[Show help]'
}

# update subcommand completion
_claude_code_update() {
    _arguments \
        {-h,--help}'[Show help]'
}

# Register completion functions
compdef _claude_code claude-code
compdef _claude_code claude
compdef _claude_code cc

# Add common aliases
# alias cc='claude'
alias cl='claude'
alias ccc='claude chat'
alias cca='claude api'
alias cccfg='claude config'
