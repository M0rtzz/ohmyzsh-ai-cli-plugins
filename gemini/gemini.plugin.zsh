# Gemini CLI Zsh autocompletion plugin
# Supports intelligent completion for gemini commands, including mcp and extensions subcommands

# Main completion function
_gemini_cli() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    local -a commands
    commands=(
        'mcp:Manage MCP servers'
        'extensions:Manage Gemini CLI extensions'
        'skills:Manage agent skills'
        'hooks:Manage Gemini CLI hooks'
    )

    _arguments -C \
        {-d,--debug}'[Debug mode]' \
        {-m,--model}'[Specify model]:model:' \
        {-p,--prompt}'[Run in headless mode with prompt]:prompt:' \
        {-i,--prompt-interactive}'[Continue interactive mode after executing prompt]:prompt:' \
        {-s,--sandbox}'[Run in sandbox]' \
        {-y,--yolo}'[Automatically accept all actions (YOLO mode)]' \
        '--approval-mode[Set approval mode]:mode:(default auto_edit yolo plan)' \
        '--policy[Additional policy file or directory]:policy:_files' \
        '--experimental-acp[Start agent in ACP mode]' \
        '--allowed-mcp-server-names[Allowed MCP server names]:servers:' \
        '--allowed-tools[Tools that can run without confirmation]:tools:' \
        {-e,--extensions}'[List of extensions to use]:extensions:' \
        {-l,--list-extensions}'[List all available extensions and exit]' \
        {-r,--resume}'[Resume previous session]:session:(latest)' \
        '--list-sessions[List available sessions for current project and exit]' \
        '--delete-session[Delete session by index number]:index:' \
        '--include-directories[Additional directories to include in workspace]:dir:_files -/' \
        '--screen-reader[Enable screen reader mode]' \
        {-o,--output-format}'[CLI output format]:format:(text json stream-json)' \
        '--raw-output[Disable sanitization of model output]' \
        '--accept-raw-output-risk[Suppress warning for --raw-output]' \
        {-v,--version}'[Show version number]' \
        {-h,--help}'[Show help information]' \
        '1: :->command' \
        '*::arg:->args'

    case $state in
        command)
            _describe -t commands 'gemini commands' commands
            ;;
        args)
            case $line[1] in
                mcp)
                    _gemini_cli_mcp
                    ;;
                extensions)
                    _gemini_cli_extensions
                    ;;
                skills)
                    _gemini_cli_skills
                    ;;
                hooks)
                    _gemini_cli_hooks
                    ;;
            esac
            ;;
    esac
}

# mcp subcommand completion
_gemini_cli_mcp() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    local -a mcp_cmds
    mcp_cmds=(
        'add:Add server'
        'remove:Remove server'
        'list:List all configured MCP servers'
        'enable:Enable MCP server'
        'disable:Disable MCP server'
    )

    _arguments -C \
        {-d,--debug}'[Debug mode]' \
        {-h,--help}'[Show help]' \
        '1: :->command' \
        '*::arg:->args'

    case $state in
        command)
            _describe -t mcp_cmds 'mcp commands' mcp_cmds
            ;;
        args)
            case $line[1] in
                add)
                    _gemini_cli_mcp_add
                    ;;
                remove)
                    _gemini_cli_mcp_remove
                    ;;
                list)
                    _arguments \
                        {-d,--debug}'[Debug mode]' \
                        {-h,--help}'[Show help]'
                    ;;
                enable)
                    _gemini_cli_mcp_enable
                    ;;
                disable)
                    _gemini_cli_mcp_disable
                    ;;
            esac
            ;;
    esac
}

# mcp add subcommand completion
_gemini_cli_mcp_add() {
    _arguments \
        {-d,--debug}'[Debug mode]' \
        {-s,--scope}'[Configuration scope]:scope:(user project)' \
        {-t,--transport}'[Transport type]:transport:(stdio sse http)' \
        '--type[Transport type alias]:transport:(stdio sse http)' \
        {-e,--env}'[Set environment variable]:env:' \
        {-H,--header}'[Set HTTP header]:header:' \
        '--timeout[Connection timeout in milliseconds]:timeout:' \
        '--trust[Trust server (skip all confirmations)]' \
        '--description[Server description]:description:' \
        '--include-tools[List of tools to include]:tools:' \
        '--exclude-tools[List of tools to exclude]:tools:' \
        {-h,--help}'[Show help]' \
        '1:name:' \
        '2:commandOrUrl:' \
        '*:args:'
}

# mcp remove subcommand completion
_gemini_cli_mcp_remove() {
    local -a servers
    # Dynamically get list of configured MCP servers
    servers=($(gemini mcp list 2>/dev/null | grep -E '^\s+\w+' | awk '{print $1":Remove MCP server"}'))

    _arguments \
        {-d,--debug}'[Debug mode]' \
        {-s,--scope}'[Configuration scope]:scope:(user project)' \
        {-h,--help}'[Show help]' \
        '1: :->server'

    case $state in
        server)
            if (( ${#servers} > 0 )); then
                _describe -t servers 'MCP servers' servers
            fi
            ;;
    esac
}

# mcp enable subcommand completion
_gemini_cli_mcp_enable() {
    local -a servers
    servers=($(gemini mcp list 2>/dev/null | grep -E '^\s+\w+' | awk '{print $1":Enable MCP server"}'))

    _arguments \
        {-d,--debug}'[Debug mode]' \
        '--session[Clear session-only disable]' \
        {-h,--help}'[Show help]' \
        '1: :->server'

    case $state in
        server)
            if (( ${#servers} > 0 )); then
                _describe -t servers 'MCP servers' servers
            fi
            ;;
    esac
}

# mcp disable subcommand completion
_gemini_cli_mcp_disable() {
    local -a servers
    servers=($(gemini mcp list 2>/dev/null | grep -E '^\s+\w+' | awk '{print $1":Disable MCP server"}'))

    _arguments \
        {-d,--debug}'[Debug mode]' \
        '--session[Disable for current session only]' \
        {-h,--help}'[Show help]' \
        '1: :->server'

    case $state in
        server)
            if (( ${#servers} > 0 )); then
                _describe -t servers 'MCP servers' servers
            fi
            ;;
    esac
}

# extensions subcommand completion
_gemini_cli_extensions() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    local -a extensions_cmds
    extensions_cmds=(
        'install:Install extension from git repository or local path'
        'uninstall:Uninstall extension'
        'list:List installed extensions'
        'update:Update all extensions or specified extension to latest version'
        'disable:Disable extension'
        'enable:Enable extension'
        'link:Link extension from local path'
        'new:Create new extension from template'
        'validate:Validate extension at local path'
        'config:Configure extension settings'
    )

    _arguments -C \
        {-d,--debug}'[Debug mode]' \
        {-h,--help}'[Show help]' \
        '1: :->command' \
        '*::arg:->args'

    case $state in
        command)
            _describe -t extensions_cmds 'extensions commands' extensions_cmds
            ;;
        args)
            case $line[1] in
                install)
                    _gemini_cli_extensions_install
                    ;;
                uninstall)
                    _gemini_cli_extensions_uninstall
                    ;;
                list)
                    _gemini_cli_extensions_list
                    ;;
                update)
                    _gemini_cli_extensions_update
                    ;;
                disable)
                    _gemini_cli_extensions_disable
                    ;;
                enable)
                    _gemini_cli_extensions_enable
                    ;;
                link)
                    _gemini_cli_extensions_link
                    ;;
                new|validate)
                    _arguments \
                        {-d,--debug}'[Debug mode]' \
                        {-h,--help}'[Show help]' \
                        '*:path:_files'
                    ;;
                config)
                    _gemini_cli_extensions_config
                    ;;
            esac
            ;;
    esac
}

# extensions install subcommand completion
_gemini_cli_extensions_install() {
    _arguments \
        {-d,--debug}'[Debug mode]' \
        '--ref[Git ref to install]:ref:' \
        '--auto-update[Enable auto-update]' \
        '--pre-release[Enable pre-release versions]' \
        '--consent[Confirm security risks and skip confirmation prompts]' \
        {-h,--help}'[Show help]' \
        '1:source:_files'
}

# extensions list subcommand completion
_gemini_cli_extensions_list() {
    _arguments \
        {-d,--debug}'[Debug mode]' \
        {-o,--output-format}'[Output format]:format:(text json)' \
        {-h,--help}'[Show help]'
}

# extensions link subcommand completion
_gemini_cli_extensions_link() {
    _arguments \
        {-d,--debug}'[Debug mode]' \
        '--consent[Skip confirmation prompts]' \
        {-h,--help}'[Show help]' \
        '1:path:_files'
}

# extensions config subcommand completion
_gemini_cli_extensions_config() {
    local -a extensions
    extensions=($(gemini extensions list 2>/dev/null | grep -E '^\s+\w+' | awk '{print $1":Configure extension"}'))

    _arguments \
        {-d,--debug}'[Debug mode]' \
        '--scope[Settings scope]:scope:(user workspace)' \
        {-h,--help}'[Show help]' \
        '1: :->extension' \
        '2:setting:'

    case $state in
        extension)
            if (( ${#extensions} > 0 )); then
                _describe -t extensions 'installed extensions' extensions
            fi
            ;;
    esac
}

# extensions uninstall subcommand completion
_gemini_cli_extensions_uninstall() {
    local -a extensions
    # Dynamically get list of installed extensions
    extensions=($(gemini extensions list 2>/dev/null | grep -E '^\s+\w+' | awk '{print $1":Uninstall extension"}'))

    _arguments \
        {-d,--debug}'[Debug mode]' \
        {-h,--help}'[Show help]' \
        '*: :->extension'

    case $state in
        extension)
            if (( ${#extensions} > 0 )); then
                _describe -t extensions 'installed extensions' extensions
            fi
            ;;
    esac
}

# extensions update subcommand completion
_gemini_cli_extensions_update() {
    local -a extensions
    extensions=($(gemini extensions list 2>/dev/null | grep -E '^\s+\w+' | awk '{print $1":Update extension"}'))

    _arguments \
        {-d,--debug}'[Debug mode]' \
        '--all[Update all extensions]' \
        {-h,--help}'[Show help]' \
        '1: :->extension'

    case $state in
        extension)
            if (( ${#extensions} > 0 )); then
                _describe -t extensions 'installed extensions' extensions
            fi
            ;;
    esac
}

# extensions disable subcommand completion
_gemini_cli_extensions_disable() {
    local -a extensions
    extensions=($(gemini extensions list 2>/dev/null | grep -E '^\s+\w+' | awk '{print $1":Disable extension"}'))

    _arguments \
        {-d,--debug}'[Debug mode]' \
        '--scope[Scope]:scope:(user workspace)' \
        {-h,--help}'[Show help]' \
        '1: :->extension'

    case $state in
        extension)
            if (( ${#extensions} > 0 )); then
                _describe -t extensions 'installed extensions' extensions
            fi
            ;;
    esac
}

# extensions enable subcommand completion
_gemini_cli_extensions_enable() {
    local -a extensions
    extensions=($(gemini extensions list 2>/dev/null | grep -E '^\s+\w+' | awk '{print $1":Enable extension"}'))

    _arguments \
        {-d,--debug}'[Debug mode]' \
        '--scope[Scope]:scope:(user workspace)' \
        {-h,--help}'[Show help]' \
        '1: :->extension'

    case $state in
        extension)
            if (( ${#extensions} > 0 )); then
                _describe -t extensions 'installed extensions' extensions
            fi
            ;;
    esac
}

# hooks subcommand completion
_gemini_cli_hooks() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    local -a hooks_cmds
    hooks_cmds=(
        'migrate:Migrate hooks from Claude Code'
    )

    _arguments -C \
        {-d,--debug}'[Debug mode]' \
        {-h,--help}'[Show help]' \
        '1: :->command' \
        '*::arg:->args'

    case $state in
        command)
            _describe -t hooks_cmds 'hooks commands' hooks_cmds
            ;;
        args)
            case $line[1] in
                migrate)
                    _gemini_cli_hooks_migrate
                    ;;
            esac
            ;;
    esac
}

_gemini_cli_hooks_migrate() {
    _arguments \
        {-d,--debug}'[Debug mode]' \
        '--from-claude[Migrate from Claude Code hooks]' \
        {-h,--help}'[Show help]'
}

# skills subcommand completion
_gemini_cli_skills() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    local -a skills_cmds
    skills_cmds=(
        'list:List discovered agent skills'
        'enable:Enable an agent skill'
        'disable:Disable an agent skill'
        'install:Install an agent skill'
        'link:Link an agent skill from local path'
        'uninstall:Uninstall an agent skill'
    )

    _arguments -C \
        {-d,--debug}'[Debug mode]' \
        {-h,--help}'[Show help]' \
        '1: :->command' \
        '*::arg:->args'

    case $state in
        command)
            _describe -t skills_cmds 'skills commands' skills_cmds
            ;;
        args)
            case $line[1] in
                list)
                    _gemini_cli_skills_list
                    ;;
                enable)
                    _gemini_cli_skills_enable
                    ;;
                disable)
                    _gemini_cli_skills_disable
                    ;;
                install)
                    _gemini_cli_skills_install
                    ;;
                link)
                    _gemini_cli_skills_link
                    ;;
                uninstall)
                    _gemini_cli_skills_uninstall
                    ;;
            esac
            ;;
    esac
}

_gemini_cli_skills_list() {
    _arguments \
        {-d,--debug}'[Debug mode]' \
        '--all[Show all skills including built-in]' \
        {-h,--help}'[Show help]'
}

_gemini_cli_skills_enable() {
    _arguments \
        {-d,--debug}'[Debug mode]' \
        {-h,--help}'[Show help]' \
        '1:name:'
}

_gemini_cli_skills_disable() {
    _arguments \
        {-d,--debug}'[Debug mode]' \
        {-s,--scope}'[Scope]:scope:(user workspace)' \
        {-h,--help}'[Show help]' \
        '1:name:'
}

_gemini_cli_skills_install() {
    _arguments \
        {-d,--debug}'[Debug mode]' \
        '--scope[Install scope]:scope:(user workspace)' \
        '--path[Sub-path within repository]:path:' \
        '--consent[Skip confirmation prompts]' \
        {-h,--help}'[Show help]' \
        '1:source:_files'
}

_gemini_cli_skills_link() {
    _arguments \
        {-d,--debug}'[Debug mode]' \
        '--scope[Link scope]:scope:(user workspace)' \
        '--consent[Skip confirmation prompts]' \
        {-h,--help}'[Show help]' \
        '1:path:_files -/'
}

_gemini_cli_skills_uninstall() {
    _arguments \
        {-d,--debug}'[Debug mode]' \
        '--scope[Uninstall scope]:scope:(user workspace)' \
        {-h,--help}'[Show help]' \
        '1:name:'
}

# Register completion functions
compdef _gemini_cli gemini
compdef _gemini_cli gm

# Add common aliases
alias gm='gemini'
alias gmm='gemini mcp'
alias gme='gemini extensions'
