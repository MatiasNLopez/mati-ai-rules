#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# Gentleman Extends Rules — Installer
# Extension rules for Claude Code / OpenCode
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_DIR="${SCRIPT_DIR}/rules"

# ── Colors (Rose Pine palette) ───────────────

RED=$'\033[38;2;235;111;146m'     # Love #eb6f92
GREEN=$'\033[38;2;156;207;216m'   # Foam #9ccfd8
YELLOW=$'\033[38;2;241;202;147m'  # Gold #f1ca93
CYAN=$'\033[38;2;196;167;231m'    # Iris #c4a7e7
MAUVE=$'\033[38;2;235;188;186m'   # Rose #ebbcba
DIM=$'\033[38;2;144;140;170m'     # Muted #908caa
BOLD=$'\033[1m'
NC=$'\033[0m'

# ── Helpers ──────────────────────────────────

info()    { printf "%s\n" "${CYAN}ℹ ${NC}$1"; }
success() { printf "%s\n" "${GREEN}✔ ${NC}$1"; }
warn()    { printf "%s\n" "${YELLOW}⚠ ${NC}$1"; }
error()   { printf "%s\n" "${RED}✖ ${NC}$1"; }
ask()     { printf "%s " "${BOLD}$1${NC}"; }

banner() {
    printf "%s\n" "${CYAN}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║                ███╗   ███╗ █████╗ ████████╗██╗             ║
║                ████╗ ████║██╔══██╗╚══██╔══╝██║             ║
║                ██╔████╔██║███████║   ██║   ██║             ║
║                ██║╚██╔╝██║██╔══██║   ██║   ██║             ║
║                ██║ ╚═╝ ██║██║  ██║   ██║   ██║             ║
║                ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝             ║
║                                                            ║
║               █████╗ ██╗        ██╗  ██╗██╗████████╗       ║
║              ██╔══██╗██║        ██║ ██╔╝██║╚══██╔══╝       ║
║              ███████║██║        █████╔╝ ██║   ██║          ║
║              ██╔══██║██║        ██╔═██╗ ██║   ██║          ║
║              ██║  ██║██║        ██║  ██╗██║   ██║          ║
║              ╚═╝  ╚═╝╚═╝        ╚═╝  ╚═╝╚═╝   ╚═╝          ║
║                                                            ║
║                       MATI AI KIT                          ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    printf "%s\n\n" "${NC}"
    printf "   %s\n\n" "${DIM}Reglas de extensión para tu agente de IA${NC}"
}

# ── Verify rule files exist ──────────────────

check_rules_dir() {
    if [[ ! -d "$RULES_DIR" ]]; then
        error "No se encontró el directorio de reglas: ${RULES_DIR}"
        error "¿Estás corriendo el script desde el repo clonado?"
        exit 1
    fi
    for f in rtk.md gitignore.md expertise.md etendo-rules.md etendo-skills.md etendo-expertise.md postgres.md postgres-mcp.json orchestrator-optimized.md; do
        if [[ ! -f "${RULES_DIR}/${f}" ]]; then
            error "Falta el archivo de regla: rules/${f}"
            exit 1
        fi
    done
}

# ── Rule content loaders ─────────────────────

get_rtk_content() {
    cat "${RULES_DIR}/rtk.md"
}

get_gitignore_content() {
    cat "${RULES_DIR}/gitignore.md"
}

get_expertise_content() {
    if [[ -n "${CUSTOM_EXPERTISE:-}" ]]; then
        printf "## Expertise\n\n%s\n" "${CUSTOM_EXPERTISE}"
    else
        cat "${RULES_DIR}/expertise.md"
    fi
}

get_etendo_rules_content() {
    cat "${RULES_DIR}/etendo-rules.md"
}

get_etendo_skills_content() {
    cat "${RULES_DIR}/etendo-skills.md"
}

get_etendo_expertise_content() {
    if [[ -n "${CUSTOM_ETENDO_EXPERTISE:-}" ]]; then
        printf "## Expertise\n\n%s\n" "${CUSTOM_ETENDO_EXPERTISE}"
    else
        cat "${RULES_DIR}/etendo-expertise.md"
    fi
}

get_postgres_content() {
    cat "${RULES_DIR}/postgres.md"
}

get_postgres_mcp_config() {
    cat "${RULES_DIR}/postgres-mcp.json"
}

get_orchestrator_content() {
    cat "${RULES_DIR}/orchestrator-optimized.md"
}

# ── Installation functions ───────────────────

rule_exists() {
    local file="$1"
    local marker="$2"
    [[ -f "$file" ]] && grep -qF "$marker" "$file"
}

# Prompt the user for conflict resolution on an existing rule.
# Returns via CONFLICT_ACTION: "overwrite", "extend", "skip"
ask_conflict_action() {
    local rule_name="$1"
    warn "La regla '${rule_name}' ya está instalada."
    printf "  %s Sobreescribir (reemplazar por la nueva)\n" "${CYAN}[s]${NC}"
    printf "  %s Extender (agregar al contenido existente)\n" "${CYAN}[e]${NC}"
    printf "  %s Saltear (no tocar)\n" "${CYAN}[n]${NC}"
    ask "¿Qué hacemos? (s/e/n):"
    local resp
    read -r resp
    case "$resp" in
        s|S) CONFLICT_ACTION="overwrite" ;;
        e|E) CONFLICT_ACTION="extend" ;;
        *)   CONFLICT_ACTION="skip" ;;
    esac
}

# Helper: smart merge of existing lines with new content.
# Comparison in 3 levels:
#   1. Prefix: existing is prefix of new → replace with the more complete one
#   2. Full substring: new is already embedded in existing → skip
#   3. Partial substring: existing contains shorter version of new → upgrade in-place
# If no match → append as new line at the end of the section.
_extend_merge_and_write() {
    local tmp_file="$1"
    local -n _existing="$2"
    local new_content="$3"

    # Trim trailing blank lines from buffer
    local trim_end=${#_existing[@]}
    while [[ $trim_end -gt 0 ]] && [[ -z "${_existing[$((trim_end-1))]}" ]]; do
        trim_end=$((trim_end - 1))
    done

    local changes_made=0
    local -a lines_to_add=()

    while IFS= read -r new_line; do
        [[ -z "$new_line" ]] && continue
        # Normalize: strip trailing . and whitespace for comparison
        local new_norm="${new_line%.}"
        new_norm="${new_norm%"${new_norm##*[^[:space:]]}"}"

        local matched=0
        for ((i=0; i<trim_end; i++)); do
            [[ -z "${_existing[$i]}" ]] && continue
            local ex_norm="${_existing[$i]%.}"
            ex_norm="${ex_norm%"${ex_norm##*[^[:space:]]}"}"

            # Exact match → skip
            if [[ "$new_norm" == "$ex_norm" ]]; then
                matched=1; break
            fi
            # Existing is prefix of new → new is more complete, replace entire line
            if [[ "$new_norm" == "${ex_norm}"* ]]; then
                _existing[$i]="$new_line"
                changes_made=1
                matched=1; break
            fi
            # New is prefix of existing → existing already more complete, skip
            if [[ "$ex_norm" == "${new_norm}"* ]]; then
                matched=1; break
            fi
            # Full new content already embedded as substring in existing → skip
            if [[ "$ex_norm" == *"$new_norm"* ]]; then
                matched=1; break
            fi
            # Partial substring: existing has shorter version of new
            # Ex: existing="...Zellij. Backend..., PostgreSQL."
            #     new="Backend..., PostgreSQL, Kafka."
            # → replace "Backend..., PostgreSQL." with "Backend..., PostgreSQL, Kafka."
            local try_norm="$new_norm"
            while [[ "$try_norm" == *","* ]]; do
                try_norm="${try_norm%,*}"                       # strip from last comma
                try_norm="${try_norm%"${try_norm##*[^[:space:]]}"}"  # rtrim
                if [[ "$ex_norm" == *"$try_norm"* ]]; then
                    # Found partial embedded version → upgrade in-place
                    local old_with_dot="${try_norm}."
                    if [[ "${_existing[$i]}" == *"$old_with_dot"* ]]; then
                        _existing[$i]="${_existing[$i]/${old_with_dot}/${new_line}}"
                    else
                        _existing[$i]="${_existing[$i]/${try_norm}/${new_norm}}"
                    fi
                    changes_made=1
                    matched=1; break
                fi
            done
            [[ $matched -eq 1 ]] && break
        done

        if [[ $matched -eq 0 ]]; then
            lines_to_add+=("$new_line")
            changes_made=1
        fi
    done <<< "$new_content"

    # Write existing lines (with replacements applied)
    for ((i=0; i<trim_end; i++)); do
        printf "%s\n" "${_existing[$i]}" >> "$tmp_file"
    done

    # Append genuinely new lines at the end of the section
    if [[ ${#lines_to_add[@]} -gt 0 ]]; then
        for nl in "${lines_to_add[@]}"; do
            printf "%s\n" "$nl" >> "$tmp_file"
        done
    fi

    if [[ $changes_made -eq 0 ]]; then
        printf "  %s El contenido ya existe, nada que agregar\n" "✔" >&2
    fi
}

# Replace a block in-place (between start_marker and next ## section or EOF).
# Mode "replace": replace block with new_content.
# Mode "extend": smart merge — add only what's missing, replace incomplete lines.
# Mode "remove": delete block without inserting anything.
replace_block_inplace() {
    local file="$1"
    local start_marker="$2"
    local new_content="$3"       # new content (empty for remove)
    local mode="${4:-replace}"   # replace | extend | remove

    local tmp
    tmp=$(mktemp)
    local in_block=0
    local done_block=0

    # For extend mode: buffer existing block lines
    local -a existing_lines=()

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ $done_block -eq 0 ]] && [[ "$line" == *"$start_marker"* ]]; then
            in_block=1
            if [[ "$mode" == "replace" ]]; then
                printf "%s\n" "$new_content" >> "$tmp"
                done_block=1
            elif [[ "$mode" == "extend" ]]; then
                # Buffer the header line, don't write yet
                existing_lines+=("$line")
            fi
            continue
        fi

        if [[ $in_block -eq 1 ]]; then
            # Detect end of block: next ## section
            if [[ "$line" =~ ^##\  ]]; then
                in_block=0
                done_block=1
                if [[ "$mode" == "extend" ]]; then
                    _extend_merge_and_write "$tmp" existing_lines "$new_content"
                fi
                # Blank line before the next section
                printf "\n%s\n" "$line" >> "$tmp"
                continue
            fi

            if [[ "$mode" == "extend" ]]; then
                # Buffer all block lines (including blanks)
                existing_lines+=("$line")
            fi
            # In replace/remove mode, old block lines are discarded
            continue
        fi

        printf "%s\n" "$line" >> "$tmp"
    done < "$file"

    # If block was the last one (no next ## section found)
    if [[ $in_block -eq 1 ]] && [[ $done_block -eq 0 ]]; then
        if [[ "$mode" == "extend" ]]; then
            _extend_merge_and_write "$tmp" existing_lines "$new_content"
        fi
    fi

    mv "$tmp" "$file"
}

ensure_file() {
    local file="$1"
    local dir
    dir=$(dirname "$file")

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            error "No se pudo crear el directorio: ${dir}"
            return 1
        }
    fi

    if [[ ! -f "$file" ]]; then
        touch "$file" || {
            error "No se pudo crear el archivo: ${file}"
            return 1
        }
        info "Archivo creado: ${file}"
    fi

    if [[ ! -w "$file" ]]; then
        error "El archivo no tiene permisos de escritura: ${file}"
        return 1
    fi

    return 0
}

# ── Per-rule installers ──────────────────────

install_rtk() {
    local file="$1"
    local marker="## RTK"
    local content
    content=$(get_rtk_content)

    if rule_exists "$file" "$marker"; then
        # Detectar versión anterior (tabla expandida) y sugerir sobreescribir
        if grep -qF "| Instead of | Use |" "$file"; then
            warn "Se detectó la versión anterior (tabla expandida) de RTK."
            printf "  %s\n" "${DIM}Se recomienda actualizar a la versión comprimida.${NC}"
        fi
        ask_conflict_action "RTK"
        case "$CONFLICT_ACTION" in
            skip)
                info "Saltando RTK."
                return 0
                ;;
            overwrite)
                replace_block_inplace "$file" "$marker" "$content" "replace"
                success "RTK sobreescrito (misma posición)."
                INSTALLED_RULES+=("RTK — Token-Optimized CLI (sobreescrito)")
                return 0
                ;;
            extend)
                local extra_text
                extra_text=$(printf "%s" "$content" | tail -n +3)
                replace_block_inplace "$file" "$marker" "$extra_text" "extend"
                success "RTK extendido."
                INSTALLED_RULES+=("RTK — Token-Optimized CLI (extendido)")
                return 0
                ;;
        esac
    fi

    # New install: RTK goes at the top of the file
    # New section → blank line after if content follows
    if [[ -s "$file" ]]; then
        local tmp
        tmp=$(mktemp)
        printf "%s\n\n" "$content" > "$tmp"
        cat "$file" >> "$tmp"
        mv "$tmp" "$file"
    else
        printf "%s\n" "$content" > "$file"
    fi

    success "RTK instalado."
    INSTALLED_RULES+=("RTK — Token-Optimized CLI")
}

install_gitignore() {
    local file="$1"
    local marker="ALWAYS respect"
    local content
    content=$(get_gitignore_content)

    if rule_exists "$file" "$marker"; then
        ask_conflict_action ".gitignore respect"
        case "$CONFLICT_ACTION" in
            skip)
                info "Saltando .gitignore."
                return 0
                ;;
            overwrite)
                # Replace existing line in-place
                local tmp
                tmp=$(mktemp)
                while IFS= read -r line || [[ -n "$line" ]]; do
                    if [[ "$line" == *"$marker"* ]]; then
                        printf "%s\n" "$content" >> "$tmp"
                    else
                        printf "%s\n" "$line" >> "$tmp"
                    fi
                done < "$file"
                mv "$tmp" "$file"
                success ".gitignore respect sobreescrito (misma posición)."
                INSTALLED_RULES+=(".gitignore respect rule (sobreescrito)")
                return 0
                ;;
            extend)
                # Collect existing block lines (from marker to next bullet or section)
                local -a existing_block=()
                local in_marker_block=0
                while IFS= read -r line || [[ -n "$line" ]]; do
                    if [[ "$line" == *"$marker"* ]]; then
                        in_marker_block=1
                        existing_block+=("$line")
                        continue
                    fi
                    if [[ $in_marker_block -eq 1 ]]; then
                        if [[ "$line" =~ ^-\ \*\* ]] || [[ "$line" =~ ^## ]]; then
                            break
                        fi
                        [[ -n "$line" ]] && existing_block+=("$line")
                    fi
                done < "$file"

                # Smart merge: compare by normalized prefix (not exact match)
                local -a lines_to_add=()
                local changes_made=0
                while IFS= read -r new_line || [[ -n "$new_line" ]]; do
                    [[ -z "$new_line" ]] && continue
                    local new_norm="${new_line%.}"
                    new_norm="${new_norm%"${new_norm##*[^[:space:]]}"}"

                    local matched=0
                    for idx in "${!existing_block[@]}"; do
                        [[ -z "${existing_block[$idx]}" ]] && continue
                        local ex_norm="${existing_block[$idx]%.}"
                        ex_norm="${ex_norm%"${ex_norm##*[^[:space:]]}"}"

                        if [[ "$new_norm" == "$ex_norm" ]]; then
                            matched=1; break
                        fi
                        # Existing is prefix of new → new is more complete, replace
                        if [[ "$new_norm" == "${ex_norm}"* ]]; then
                            existing_block[$idx]="$new_line"
                            changes_made=1
                            matched=1; break
                        fi
                        # New is prefix of existing → existing already has everything, skip
                        if [[ "$ex_norm" == "${new_norm}"* ]]; then
                            matched=1; break
                        fi
                    done

                    if [[ $matched -eq 0 ]]; then
                        lines_to_add+=("$new_line")
                        changes_made=1
                    fi
                done <<< "$content"

                if [[ $changes_made -eq 0 ]]; then
                    printf "  %s El contenido ya existe, nada que agregar\n" "✔"
                    INSTALLED_RULES+=(".gitignore respect rule (ya existía)")
                    return 0
                fi

                # Rewrite: replace existing line with merged version
                local tmp
                tmp=$(mktemp)
                while IFS= read -r line || [[ -n "$line" ]]; do
                    if [[ "$line" == *"$marker"* ]]; then
                        for el in "${existing_block[@]}"; do
                            printf "%s\n" "$el" >> "$tmp"
                        done
                        for add_line in "${lines_to_add[@]}"; do
                            printf "%s\n" "$add_line" >> "$tmp"
                        done
                    else
                        printf "%s\n" "$line" >> "$tmp"
                    fi
                done < "$file"
                mv "$tmp" "$file"
                success ".gitignore respect extendido."
                INSTALLED_RULES+=(".gitignore respect rule (extendido)")
                return 0
                ;;
        esac
    fi

    # New item in existing section: right after last item, no blank lines
    if grep -q "^## Rules" "$file"; then
        local tmp
        tmp=$(mktemp)
        local in_rules=0
        local inserted=0
        local prev_was_rule=0
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "## Rules"* ]]; then
                in_rules=1
                printf "%s\n" "$line" >> "$tmp"
                continue
            fi
            if [[ $in_rules -eq 1 ]]; then
                # If line is an item (starts with -)
                if [[ "$line" == -* ]]; then
                    prev_was_rule=1
                    printf "%s\n" "$line" >> "$tmp"
                    continue
                fi
                # If we stopped seeing items and haven't inserted yet
                if [[ $prev_was_rule -eq 1 ]] && [[ $inserted -eq 0 ]]; then
                    printf "%s\n" "$content" >> "$tmp"
                    inserted=1
                    in_rules=0
                fi
            fi
            printf "%s\n" "$line" >> "$tmp"
        done < "$file"
        if [[ $inserted -eq 0 ]]; then
            printf "%s\n" "$content" >> "$tmp"
        fi
        mv "$tmp" "$file"
    else
        # New section: blank line before and after the header
        printf "\n## Rules\n\n%s\n" "$content" >> "$file"
    fi

    success ".gitignore respect instalado."
    INSTALLED_RULES+=(".gitignore respect rule")
}

install_expertise() {
    local file="$1"
    local marker="## Expertise"
    local content
    content=$(get_expertise_content)

    if rule_exists "$file" "$marker"; then
        ask_conflict_action "Expertise"
        case "$CONFLICT_ACTION" in
            skip)
                info "Saltando Expertise."
                return 0
                ;;
            overwrite)
                replace_block_inplace "$file" "$marker" "$content" "replace"
                success "Expertise sobreescrito (misma posición)."
                INSTALLED_RULES+=("Expertise (sobreescrito)")
                return 0
                ;;
            extend)
                local extra_text
                extra_text=$(printf "%s" "$content" | tail -n +3)
                replace_block_inplace "$file" "$marker" "$extra_text" "extend"
                success "Expertise extendido."
                INSTALLED_RULES+=("Expertise (extendido)")
                return 0
                ;;
        esac
    fi

    # New section: blank line above if content exists
    printf "\n%s\n" "$content" >> "$file"

    success "Expertise instalado."
    INSTALLED_RULES+=("Expertise")
}

# Install Etendo exclusion rule INSIDE ## Rules (extending)
install_etendo_rules() {
    local file="$1"
    local marker="Etendo/Openbravo projects:"
    local content
    content=$(get_etendo_rules_content)

    if rule_exists "$file" "$marker"; then
        ask_conflict_action "Etendo exclusion rule"
        case "$CONFLICT_ACTION" in
            skip)
                info "Saltando regla de exclusión Etendo."
                return 0
                ;;
            overwrite)
                # Replace line in-place
                local tmp
                tmp=$(mktemp)
                while IFS= read -r line || [[ -n "$line" ]]; do
                    if [[ "$line" == *"$marker"* ]]; then
                        printf "%s\n" "$content" >> "$tmp"
                    else
                        printf "%s\n" "$line" >> "$tmp"
                    fi
                done < "$file"
                mv "$tmp" "$file"
                success "Regla exclusión Etendo sobreescrita (misma posición)."
                INSTALLED_RULES+=("Etendo exclusion rule (sobreescrito)")
                return 0
                ;;
            extend)
                # Collect existing block lines (from marker to next bullet or section)
                local -a existing_block=()
                local in_marker_block=0
                while IFS= read -r line || [[ -n "$line" ]]; do
                    if [[ "$line" == *"$marker"* ]]; then
                        in_marker_block=1
                        existing_block+=("$line")
                        continue
                    fi
                    if [[ $in_marker_block -eq 1 ]]; then
                        # End of block: next bullet (- **) or section (##)
                        if [[ "$line" =~ ^-\ \*\* ]] || [[ "$line" =~ ^## ]]; then
                            break
                        fi
                        [[ -n "$line" ]] && existing_block+=("$line")
                    fi
                done < "$file"

                # Smart merge: compare by normalized prefix (not exact match)
                local -a lines_to_add=()
                local changes_made=0
                while IFS= read -r new_line || [[ -n "$new_line" ]]; do
                    [[ -z "$new_line" ]] && continue
                    local new_norm="${new_line%.}"
                    new_norm="${new_norm%"${new_norm##*[^[:space:]]}"}"

                    local matched=0
                    for idx in "${!existing_block[@]}"; do
                        [[ -z "${existing_block[$idx]}" ]] && continue
                        local ex_norm="${existing_block[$idx]%.}"
                        ex_norm="${ex_norm%"${ex_norm##*[^[:space:]]}"}"

                        if [[ "$new_norm" == "$ex_norm" ]]; then
                            matched=1; break
                        fi
                        # Existing is prefix of new → new is more complete, replace
                        if [[ "$new_norm" == "${ex_norm}"* ]]; then
                            existing_block[$idx]="$new_line"
                            changes_made=1
                            matched=1; break
                        fi
                        # New is prefix of existing → existing already has everything, skip
                        if [[ "$ex_norm" == "${new_norm}"* ]]; then
                            matched=1; break
                        fi
                    done

                    if [[ $matched -eq 0 ]]; then
                        lines_to_add+=("$new_line")
                        changes_made=1
                    fi
                done <<< "$content"

                if [[ $changes_made -eq 0 ]]; then
                    printf "  %s El contenido ya existe, nada que agregar\n" "✔"
                    INSTALLED_RULES+=("Etendo exclusion rule (ya existía)")
                    return 0
                fi

                # Rewrite: replace existing line with merged version
                local tmp
                tmp=$(mktemp)
                while IFS= read -r line || [[ -n "$line" ]]; do
                    if [[ "$line" == *"$marker"* ]]; then
                        for el in "${existing_block[@]}"; do
                            printf "%s\n" "$el" >> "$tmp"
                        done
                        for add_line in "${lines_to_add[@]}"; do
                            printf "%s\n" "$add_line" >> "$tmp"
                        done
                    else
                        printf "%s\n" "$line" >> "$tmp"
                    fi
                done < "$file"
                mv "$tmp" "$file"
                success "Regla exclusión Etendo extendida."
                INSTALLED_RULES+=("Etendo exclusion rule (extendido)")
                return 0
                ;;
        esac
    fi

    # New item in existing section: right after last item, no blank lines
    if grep -q "^## Rules" "$file"; then
        local tmp
        tmp=$(mktemp)
        local in_rules=0
        local inserted=0
        local prev_was_rule=0
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "## Rules"* ]]; then
                in_rules=1
                printf "%s\n" "$line" >> "$tmp"
                continue
            fi
            if [[ $in_rules -eq 1 ]]; then
                if [[ "$line" == -* ]]; then
                    prev_was_rule=1
                    printf "%s\n" "$line" >> "$tmp"
                    continue
                fi
                if [[ $prev_was_rule -eq 1 ]] && [[ $inserted -eq 0 ]]; then
                    printf "%s\n" "$content" >> "$tmp"
                    inserted=1
                    in_rules=0
                fi
            fi
            printf "%s\n" "$line" >> "$tmp"
        done < "$file"
        if [[ $inserted -eq 0 ]]; then
            printf "%s\n" "$content" >> "$tmp"
        fi
        mv "$tmp" "$file"
    else
        printf "\n## Rules\n\n%s\n" "$content" >> "$file"
    fi

    success "Regla exclusión Etendo instalada en ## Rules."
    INSTALLED_RULES+=("Etendo exclusion rule")
}

# Install Etendo skills table as its own section
install_etendo_skills() {
    local file="$1"
    local marker="### Etendo ERP Development"
    local content
    content=$(get_etendo_skills_content)

    if rule_exists "$file" "$marker"; then
        ask_conflict_action "Etendo ERP Skills"
        case "$CONFLICT_ACTION" in
            skip)
                info "Saltando Etendo ERP Skills."
                return 0
                ;;
            overwrite)
                replace_block_inplace "$file" "$marker" "$content" "replace"
                success "Etendo ERP Skills sobreescrito (misma posición)."
                INSTALLED_RULES+=("Etendo ERP Skills (sobreescrito)")
                return 0
                ;;
            extend)
                local extra_text
                extra_text=$(printf "%s" "$content" | tail -n +3)
                replace_block_inplace "$file" "$marker" "$extra_text" "extend"
                success "Etendo ERP Skills extendido."
                INSTALLED_RULES+=("Etendo ERP Skills (extendido)")
                return 0
                ;;
        esac
    fi

    # New section: blank line before header, blank line after if another section follows
    if grep -q "^## Skills" "$file"; then
        local tmp
        tmp=$(mktemp)
        local in_skills=0
        local inserted=0
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "## Skills"* ]]; then
                in_skills=1
                printf "%s\n" "$line" >> "$tmp"
                continue
            fi
            # Insert before the next ## section (not ###)
            if [[ $in_skills -eq 1 ]] && [[ "$line" =~ ^##\  ]] && [[ ! "$line" =~ ^###\  ]] && [[ $inserted -eq 0 ]]; then
                # Blank line before new content (separate from previous)
                printf "\n%s\n" "$content" >> "$tmp"
                inserted=1
                in_skills=0
                # Blank line before the next section
                printf "\n%s\n" "$line" >> "$tmp"
                continue
            fi
            printf "%s\n" "$line" >> "$tmp"
        done < "$file"
        if [[ $inserted -eq 0 ]]; then
            printf "\n%s\n" "$content" >> "$tmp"
        fi
        mv "$tmp" "$file"
    else
        printf "\n%s\n" "$content" >> "$file"
    fi

    success "Etendo ERP Skills instalado."
    INSTALLED_RULES+=("Etendo ERP Skills")
}

install_etendo_expertise() {
    local file="$1"
    local marker="## Expertise"
    local content
    content=$(get_etendo_expertise_content)

    if rule_exists "$file" "$marker"; then
        ask_conflict_action "Expertise Backend"
        case "$CONFLICT_ACTION" in
            skip)
                info "Saltando Expertise Backend."
                return 0
                ;;
            overwrite)
                replace_block_inplace "$file" "$marker" "$content" "replace"
                success "Expertise Backend sobreescrito (misma posición)."
                INSTALLED_RULES+=("Expertise Backend (sobreescrito)")
                return 0
                ;;
            extend)
                local extra_text
                extra_text=$(printf "%s" "$content" | tail -n +3)
                replace_block_inplace "$file" "$marker" "$extra_text" "extend"
                success "Expertise Backend extendido."
                INSTALLED_RULES+=("Expertise Backend (extendido)")
                return 0
                ;;
        esac
    fi

    # New section: blank line above if content exists
    printf "\n%s\n" "$content" >> "$file"

    success "Expertise Backend instalado."
    INSTALLED_RULES+=("Expertise Backend")
}

install_postgres() {
    local file="$1"
    local marker="## PostgreSQL"
    local content
    content=$(get_postgres_content)

    if rule_exists "$file" "$marker"; then
        ask_conflict_action "PostgreSQL"
        case "$CONFLICT_ACTION" in
            skip)
                info "Saltando PostgreSQL."
                return 0
                ;;
            overwrite)
                replace_block_inplace "$file" "$marker" "$content" "replace"
                success "PostgreSQL sobreescrito (misma posición)."
                INSTALLED_RULES+=("PostgreSQL (sobreescrito)")
                return 0
                ;;
            extend)
                local extra_text
                extra_text=$(printf "%s" "$content" | tail -n +3)
                replace_block_inplace "$file" "$marker" "$extra_text" "extend"
                success "PostgreSQL extendido."
                INSTALLED_RULES+=("PostgreSQL (extendido)")
                return 0
                ;;
        esac
    fi

    # New section: blank line above if content exists
    printf "\n%s\n" "$content" >> "$file"

    success "PostgreSQL instalado."
    INSTALLED_RULES+=("PostgreSQL")
}

install_postgres_mcp() {
    local tool="$1"
    local scope_idx="$2"
    local config_file=""

    # Determine the JSON config file path
    case "$tool" in
        opencode)
            if [[ "$scope_idx" == "0" ]]; then
                config_file="${HOME}/.config/opencode/opencode.json"
            else
                config_file="$(pwd)/opencode.json"
            fi
            ;;
        claude)
            if [[ "$scope_idx" == "0" ]]; then
                config_file="${HOME}/.claude/claude_desktop_config.json"
            else
                config_file="$(pwd)/.claude/claude_desktop_config.json"
            fi
            ;;
    esac

    if ! command -v jq &>/dev/null; then
        warn "jq no está instalado. No se puede instalar la config MCP de PostgreSQL."
        warn "Instalá jq (apt install jq / brew install jq) y volvé a correr."
        return 0
    fi

    # Determine JSON key based on the tool
    local mcp_key
    if [[ "$tool" == "opencode" ]]; then
        mcp_key="mcp"
    else
        mcp_key="mcpServers"
    fi

    # Ensure directory exists
    local config_dir
    config_dir=$(dirname "$config_file")
    if [[ ! -d "$config_dir" ]]; then
        mkdir -p "$config_dir" || {
            error "No se pudo crear el directorio: ${config_dir}"
            return 0
        }
    fi

    # If file doesn't exist, create base structure
    if [[ ! -f "$config_file" ]]; then
        printf '%s\n' '{}' > "$config_file"
        info "Archivo de config creado: ${config_file}"
    fi

    # Ensure MCP key exists in the JSON
    if ! jq -e --arg k "$mcp_key" '.[$k]' "$config_file" &>/dev/null; then
        local tmp
        tmp=$(mktemp)
        jq --arg k "$mcp_key" 'if .[$k] then . else . + {($k): {}} end' "$config_file" > "$tmp" && mv "$tmp" "$config_file"
    fi

    # Check if "postgres" key already exists (via jq, not grep)
    if jq -e --arg k "$mcp_key" '.[$k].postgres' "$config_file" &>/dev/null; then
        warn "La config MCP 'postgres' ya existe en ${config_file}."
        printf "  %s Sobreescribir (reemplazar la config existente)\n" "${CYAN}[s]${NC}"
        printf "  %s Saltear (no tocar)\n" "${CYAN}[n]${NC}"
        ask "¿Qué hacemos? (s/n):"
        local resp
        read -r resp
        case "$resp" in
            s|S)
                local postgres_config
                postgres_config=$(get_postgres_mcp_config)
                local tmp
                tmp=$(mktemp)
                jq --arg k "$mcp_key" --argjson pg "$postgres_config" '.[$k] = (.[$k] | del(.postgres)) + $pg' "$config_file" > "$tmp" && mv "$tmp" "$config_file"
                success "Config MCP PostgreSQL sobreescrita en ${config_file}."
                INSTALLED_RULES+=("PostgreSQL MCP (sobreescrito)")
                return 0
                ;;
            *)
                info "Saltando config MCP PostgreSQL."
                return 0
                ;;
        esac
    fi

    # Install: merge server at the END of existing object
    local postgres_config
    postgres_config=$(get_postgres_mcp_config)
    local tmp
    tmp=$(mktemp)
    jq --arg k "$mcp_key" --argjson pg "$postgres_config" '.[$k] += $pg' "$config_file" > "$tmp" && mv "$tmp" "$config_file"

    success "Config MCP PostgreSQL instalada en ${config_file}."
    INSTALLED_RULES+=("PostgreSQL MCP")
}

install_orchestrator() {
    local file="$1"
    local marker="### Result Contract"
    local content
    content=$(get_orchestrator_content)

    if rule_exists "$file" "$marker"; then
        ask_conflict_action "Orchestrator optimized (Result Contract)"
        case "$CONFLICT_ACTION" in
            skip)
                info "Saltando Orchestrator optimized."
                return 0
                ;;
            overwrite)
                replace_block_inplace "$file" "$marker" "$content" "replace"
                success "Orchestrator optimized sobreescrito (misma posición)."
                INSTALLED_RULES+=("Orchestrator optimized — Result Contract (sobreescrito)")
                return 0
                ;;
            extend)
                local extra_text
                extra_text=$(printf "%s" "$content" | tail -n +3)
                replace_block_inplace "$file" "$marker" "$extra_text" "extend"
                success "Orchestrator optimized extendido."
                INSTALLED_RULES+=("Orchestrator optimized — Result Contract (extendido)")
                return 0
                ;;
        esac
    fi

    # New install: insert before ### Sub-Agent Launch Pattern if ## SDD Workflow exists
    if grep -q "^## SDD Workflow" "$file"; then
        if grep -q "### Sub-Agent Launch Pattern" "$file"; then
            local tmp
            tmp=$(mktemp)
            local inserted=0
            while IFS= read -r line || [[ -n "$line" ]]; do
                if [[ $inserted -eq 0 ]] && [[ "$line" == "### Sub-Agent Launch Pattern"* ]]; then
                    printf "%s\n\n" "$content" >> "$tmp"
                    inserted=1
                fi
                printf "%s\n" "$line" >> "$tmp"
            done < "$file"
            if [[ $inserted -eq 0 ]]; then
                printf "\n%s\n" "$content" >> "$tmp"
            fi
            mv "$tmp" "$file"
        else
            # SDD Workflow exists but no Sub-Agent Launch Pattern — append inside section
            printf "\n%s\n" "$content" >> "$file"
        fi
    else
        # No SDD Workflow section — append as new section
        printf "\n%s\n" "$content" >> "$file"
    fi

    success "Orchestrator optimized instalado."
    INSTALLED_RULES+=("Orchestrator optimized — Result Contract")
}

# ── Interactive checkbox ─────────────────────

# Displays a checkbox menu and stores selections in REPLY_SELECTIONS.
# Usage: checkbox_menu "Title" "option1" "option2" "option3"
# Result: REPLY_SELECTIONS is an array with selected indices (0-based).
checkbox_menu() {
    local title="$1"
    shift
    local -a options=("$@")
    local -a selected=()
    local count=${#options[@]}
    # total_items = options + 2 actions (Continue, Back)
    local total_items=$((count + 2))

    # Initialize all as unselected
    for ((i = 0; i < count; i++)); do
        selected+=("false")
    done

    local current=0

    # Hide cursor
    printf "\033[?25l"

    # Trap to restore cursor if script dies
    trap 'printf "\033[?25h"' INT TERM

    printf "\n%s\n\n" "${BOLD}${title}${NC}"

    # Function to draw the menu
    _draw_menu() {
        # Draw options with checkboxes
        for ((i = 0; i < count; i++)); do
            local checkbox
            if [[ "${selected[$i]}" == "true" ]]; then
                checkbox="${GREEN}[✔]${NC}"
            else
                checkbox="[ ]"
            fi

            if [[ $i -eq $current ]]; then
                printf "  ${CYAN}▸${NC} %s %s\n" "$checkbox" "${options[$i]}"
            else
                printf "    %s %s\n" "$checkbox" "${options[$i]}"
            fi
        done

        # Separator
        printf "\n"

        # Action: Continue
        local cont_idx=$count
        if [[ $current -eq $cont_idx ]]; then
            printf "  ${CYAN}▸${NC} ${GREEN}▶ Continuar${NC}\n"
        else
            printf "    ${DIM}▶ Continuar${NC}\n"
        fi

        # Action: Back
        local back_idx=$((count + 1))
        if [[ $current -eq $back_idx ]]; then
            printf "  ${CYAN}▸${NC} ${YELLOW}◀ Atrás${NC}\n"
        else
            printf "    ${DIM}◀ Atrás${NC}\n"
        fi

        printf "\n  ${DIM}↑↓ mover · enter seleccionar/confirmar · a todas${NC}\n"
    }

    # Function to clear and redraw
    _clear_menu() {
        # options + blank line + continue + back + blank line + help = count + 5
        local lines_to_clear=$((count + 5))
        for ((i = 0; i < lines_to_clear; i++)); do
            printf "\033[A\033[2K"
        done
    }

    # Toggle an item
    _toggle() {
        local idx="$1"
        if [[ "${selected[$idx]}" == "true" ]]; then
            selected[$idx]="false"
        else
            selected[$idx]="true"
        fi
    }

    _draw_menu

    while true; do
        # Read a character
        local key=""
        IFS= read -rsn1 key 2>/dev/null || true

        case "$key" in
            # Escape sequence (arrow keys)
            $'\x1b')
                local seq=""
                IFS= read -rsn2 -t 0.1 seq 2>/dev/null || true
                case "$seq" in
                    '[A') # Up
                        if [[ $current -gt 0 ]]; then
                            current=$((current - 1))
                        fi
                        ;;
                    '[B') # Down
                        if [[ $current -lt $((total_items - 1)) ]]; then
                            current=$((current + 1))
                        fi
                        ;;
                esac
                ;;
            # Enter: toggle checkbox OR activate action
            '')
                if [[ $current -lt $count ]]; then
                    # We're on a checkbox → toggle
                    _toggle "$current"
                elif [[ $current -eq $count ]]; then
                    # Continue
                    break
                elif [[ $current -eq $((count + 1)) ]]; then
                    # Back → return special code
                    printf "\033[?25h"
                    REPLY_SELECTIONS=("__BACK__")
                    return 0
                fi
                ;;
            # 'a' or 'A': select all
            a|A)
                for ((i = 0; i < count; i++)); do
                    selected[$i]="true"
                done
                ;;
            # Numbers: direct toggle by number
            [1-9])
                local num_idx=$((key - 1))
                if [[ $num_idx -lt $count ]]; then
                    _toggle "$num_idx"
                    current=$num_idx
                fi
                ;;
        esac

        _clear_menu
        _draw_menu
    done

    # Restore cursor
    printf "\033[?25h"

    # Store result
    REPLY_SELECTIONS=()
    for ((i = 0; i < count; i++)); do
        if [[ "${selected[$i]}" == "true" ]]; then
            REPLY_SELECTIONS+=("$i")
        fi
    done
}

# ── Main flow ────────────────────────────────

main() {
    banner
    check_rules_dir

    local step=1

    # Selection variables (declared outside loop for persistence)
    local install_rtk=false
    local install_gitignore=false
    local install_expertise=false
    local install_postgres=false
    local install_orchestrator_flag=false
    local install_etendo=false
    local install_etendo_gitignore=false
    local install_etendo_expertise=false
    local install_etendo_postgres=false
    local group_general=false
    local group_etendo=false

    while true; do
        case $step in
        # ── 1. Tool selection ──
        1)
            checkbox_menu "¿Para qué herramienta querés instalar las reglas?" \
                "Claude Code  (CLAUDE.md)" \
                "OpenCode     (AGENTS.md)"

            # Back on step 1 = exit
            if [[ ${#REPLY_SELECTIONS[@]} -gt 0 ]] && [[ "${REPLY_SELECTIONS[0]}" == "__BACK__" ]]; then
                info "Chau, nos vemos."
                exit 0
            fi

            if [[ ${#REPLY_SELECTIONS[@]} -eq 0 ]]; then
                warn "Seleccioná al menos una herramienta."
                continue
            fi

            TOOLS=()
            local has_claude=false
            local has_opencode=false
            for idx in "${REPLY_SELECTIONS[@]}"; do
                case "$idx" in
                    0) TOOLS+=("claude"); has_claude=true ;;
                    1) TOOLS+=("opencode"); has_opencode=true ;;
                esac
            done
            step=2
            ;;

        # ── 2. Scope ──
        2)
            checkbox_menu "¿Dónde lo instalamos?" \
                "Global       (configuración del usuario)" \
                "Proyecto     (directorio actual: $(pwd))"

            if [[ ${#REPLY_SELECTIONS[@]} -gt 0 ]] && [[ "${REPLY_SELECTIONS[0]}" == "__BACK__" ]]; then
                step=1
                continue
            fi

            if [[ ${#REPLY_SELECTIONS[@]} -eq 0 ]]; then
                warn "Seleccioná dónde instalar."
                continue
            fi

            local scope_idx="${REPLY_SELECTIONS[0]}"

            declare -a TARGET_FILES=()

            for tool in "${TOOLS[@]}"; do
                case "$scope_idx" in
                    0)
                        if [[ "$tool" == "claude" ]]; then
                            TARGET_FILES+=("${HOME}/.claude/CLAUDE.md")
                        else
                            TARGET_FILES+=("${HOME}/.config/opencode/AGENTS.md")
                        fi
                        ;;
                    1)
                        if [[ "$tool" == "claude" ]]; then
                            TARGET_FILES+=("$(pwd)/CLAUDE.md")
                        else
                            TARGET_FILES+=("$(pwd)/AGENTS.md")
                        fi
                        ;;
                esac
            done
            step=3
            ;;

        # ── 3. Rule group selection ──
        3)
            checkbox_menu "¿Qué grupo de reglas querés instalar?" \
                "General (RTK, .gitignore, Expertise)" \
                "Etendo/Openbravo (reglas ERP, skills, expertise backend)"

            if [[ ${#REPLY_SELECTIONS[@]} -gt 0 ]] && [[ "${REPLY_SELECTIONS[0]}" == "__BACK__" ]]; then
                step=2
                continue
            fi

            if [[ ${#REPLY_SELECTIONS[@]} -eq 0 ]]; then
                warn "Seleccioná al menos un grupo."
                continue
            fi

            group_general=false
            group_etendo=false

            for idx in "${REPLY_SELECTIONS[@]}"; do
                case "$idx" in
                    0) group_general=true ;;
                    1) group_etendo=true ;;
                esac
            done

            # Reset individual rule selections
            install_rtk=false
            install_gitignore=false
            install_expertise=false
            install_postgres=false
            install_orchestrator_flag=false
            install_etendo=false
            install_etendo_gitignore=false
            install_etendo_expertise=false
            install_etendo_postgres=false

            if $group_general; then
                step=4
            elif $group_etendo; then
                step=5
            fi
            ;;

        # ── 4. General rules ──
        4)
            # RTK solo se ofrece si OpenCode está seleccionado
            # (Claude Code usa hooks rtk-rewrite.sh, no necesita la regla)
            local -a general_opts=()
            local -a general_keys=()

            if $has_opencode; then
                general_opts+=("RTK — Token-Optimized CLI (comprimido)")
                general_keys+=("rtk")
            fi
            general_opts+=(".gitignore respect rule (excepción .env)")
            general_keys+=("gitignore")
            general_opts+=("Expertise (personalizable)")
            general_keys+=("expertise")
            general_opts+=("PostgreSQL (MCP + credential resolution)")
            general_keys+=("postgres")
            general_opts+=("Orchestrator optimized (Result Contract conciso)")
            general_keys+=("orchestrator")

            checkbox_menu "Reglas generales:" "${general_opts[@]}"

            if [[ ${#REPLY_SELECTIONS[@]} -gt 0 ]] && [[ "${REPLY_SELECTIONS[0]}" == "__BACK__" ]]; then
                step=3
                continue
            fi

            if [[ ${#REPLY_SELECTIONS[@]} -eq 0 ]]; then
                warn "Seleccioná al menos una regla."
                continue
            fi

            for idx in "${REPLY_SELECTIONS[@]}"; do
                case "${general_keys[$idx]}" in
                    rtk)          install_rtk=true ;;
                    gitignore)    install_gitignore=true ;;
                    expertise)    install_expertise=true ;;
                    postgres)     install_postgres=true ;;
                    orchestrator) install_orchestrator_flag=true ;;
                esac
            done

            # If Etendo group is also selected, go to that menu
            if $group_etendo; then
                step=5
            else
                # Exit wizard, continue with customization
                step=6
                continue
            fi
            ;;

        # ── 5. Etendo/Openbravo rules ──
        5)
            checkbox_menu "Reglas Etendo/Openbravo:" \
                "Etendo ERP rules & skills (exclusiones + tabla de skills)" \
                ".gitignore respect rule (excepción .env)" \
                "Expertise Backend (Java, Python, Hibernate, PostgreSQL)" \
                "PostgreSQL (MCP + credential resolution)"

            if [[ ${#REPLY_SELECTIONS[@]} -gt 0 ]] && [[ "${REPLY_SELECTIONS[0]}" == "__BACK__" ]]; then
                # Go back to group menu or general rules
                if $group_general; then
                    step=4
                else
                    step=3
                fi
                continue
            fi

            if [[ ${#REPLY_SELECTIONS[@]} -eq 0 ]]; then
                warn "Seleccioná al menos una regla."
                continue
            fi

            for idx in "${REPLY_SELECTIONS[@]}"; do
                case "$idx" in
                    0) install_etendo=true ;;
                    1) install_etendo_gitignore=true ;;
                    2) install_etendo_expertise=true ;;
                    3) install_etendo_postgres=true ;;
                esac
            done

            step=6
            continue
            ;;

        # ── 6. Expertise customization ──
        6)
            CUSTOM_EXPERTISE=""
            CUSTOM_ETENDO_EXPERTISE=""

            if $install_expertise; then
                printf "\n%s\n" "${BOLD}Expertise General — Personalización${NC}"
                printf "%s\n" "${DIM}Default:${NC}"
                printf "  %s\n\n" "$(tail -n +3 "${RULES_DIR}/expertise.md")"
                ask "¿Usás el default o metés el tuyo? (d = default / c = custom):"
                local exp_choice
                read -r exp_choice

                if [[ "$exp_choice" =~ ^[cC]$ ]]; then
                    ask "Dale, escribí tu expertise (una línea):"
                    read -r CUSTOM_EXPERTISE
                    if [[ -z "$CUSTOM_EXPERTISE" ]]; then
                        warn "No escribiste nada. Uso el default."
                        CUSTOM_EXPERTISE=""
                    fi
                fi
            fi

            if $install_etendo_expertise; then
                printf "\n%s\n" "${BOLD}Expertise Backend (Etendo) — Personalización${NC}"
                printf "%s\n" "${DIM}Default:${NC}"
                printf "  %s\n\n" "$(tail -n +3 "${RULES_DIR}/etendo-expertise.md")"
                ask "¿Usás el default o metés el tuyo? (d = default / c = custom):"
                local etendo_exp_choice
                read -r etendo_exp_choice

                if [[ "$etendo_exp_choice" =~ ^[cC]$ ]]; then
                    ask "Dale, escribí tu expertise backend (una línea):"
                    read -r CUSTOM_ETENDO_EXPERTISE
                    if [[ -z "$CUSTOM_ETENDO_EXPERTISE" ]]; then
                        warn "No escribiste nada. Uso el default."
                        CUSTOM_ETENDO_EXPERTISE=""
                    fi
                fi
            fi

            # Exit the wizard
            break
            ;;
        esac
    done

    # ── 7. Installation ──

    # Consolidate .gitignore: if selected in both groups, install only once
    local do_install_gitignore=false
    if $install_gitignore || $install_etendo_gitignore; then
        do_install_gitignore=true
    fi

    # Consolidate PostgreSQL: if selected in both groups, install only once
    local do_install_postgres=false
    if $install_postgres || $install_etendo_postgres; then
        do_install_postgres=true
    fi

    # Flag to install MCP config only once per tool
    local postgres_mcp_installed=false

    printf "\n%s\n" "${BOLD}═══════════════════════════════════════${NC}"
    printf "%s\n" "${BOLD}  Instalando...${NC}"
    printf "%s\n\n" "${BOLD}═══════════════════════════════════════${NC}"

    for target in "${TARGET_FILES[@]}"; do
        INSTALLED_RULES=()

        info "Archivo destino: ${BOLD}${target}${NC}"

        if ! ensure_file "$target"; then
            error "No se puede escribir en ${target}. Saltando."
            continue
        fi

        printf "\n"

        # 1. RTK (solo en archivos AGENTS.md — Claude Code usa hooks)
        if $install_rtk; then
            if [[ "$target" == *"CLAUDE.md" ]]; then
                info "RTK no se instala en CLAUDE.md (Claude Code usa hooks rtk-rewrite.sh)."
            else
                install_rtk "$target"
            fi
        fi

        # 2. .gitignore (once, shared between groups)
        if $do_install_gitignore; then
            install_gitignore "$target"
        fi

        # 3. Expertise general
        if $install_expertise; then
            install_expertise "$target"
        fi

        # 4. Etendo rules (exclusion in ## Rules) + skills (own section)
        if $install_etendo; then
            install_etendo_rules "$target"
            install_etendo_skills "$target"
        fi

        # 5. Etendo expertise
        if $install_etendo_expertise; then
            install_etendo_expertise "$target"
        fi

        # 6. PostgreSQL (once, shared between groups)
        if $do_install_postgres; then
            install_postgres "$target"
        fi

        # 7. Orchestrator optimized
        if $install_orchestrator_flag; then
            install_orchestrator "$target"
        fi

        printf "\n"

        # ── Per-file summary ──
        if [[ ${#INSTALLED_RULES[@]} -gt 0 ]]; then
            printf "%s\n" "${GREEN}${BOLD}────────────────────────────────────${NC}"
            printf "%s\n" "${GREEN}${BOLD}  Listo, crack.${NC}"
            printf "%s\n" "${GREEN}${BOLD}────────────────────────────────────${NC}"
            printf "  %s %s\n" "${BOLD}Archivo:${NC}" "${target}"
            printf "  %s\n" "${BOLD}Reglas instaladas:${NC}"
            for rule in "${INSTALLED_RULES[@]}"; do
                printf "    %s %s\n" "${GREEN}✔${NC}" "${rule}"
            done
            printf "\n"
        else
            warn "No se instaló ninguna regla en ${target}."
            printf "\n"
        fi
    done

    # PostgreSQL MCP config: install once per tool, outside the file loop
    if $do_install_postgres && ! $postgres_mcp_installed; then
        INSTALLED_RULES=()
        for tool in "${TOOLS[@]}"; do
            install_postgres_mcp "$tool" "$scope_idx"
        done
        postgres_mcp_installed=true
        if [[ ${#INSTALLED_RULES[@]} -gt 0 ]]; then
            for rule in "${INSTALLED_RULES[@]}"; do
                printf "    %s %s\n" "${GREEN}✔${NC}" "${rule}"
            done
            printf "\n"
        fi
    fi

    printf "%s\n" "${DIM}Gentleman Extends Rules — que el código te acompañe.${NC}"
}

main "$@"
