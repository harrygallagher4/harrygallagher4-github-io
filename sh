#!/bin/bash
MASK_HAS_PREV="2#10"
MASK_HAS_NEXT="2#01"
PAGE_HAS_PREV=""
PAGE_HAS_NEXT=""
PAGE_FLAGS=""

base_url="http://hgal.me"
home_page="about"

scroll=0
selection=0
page=""
paginate=0

sidebar=(
    '[a]bout me'
    '[b]log'
    '[p]rojects'
    '[c]ontrols'
    '[q]uit'
)

main_content=()

rerender() {
    clear_screen
    render
}

render() {
    render_sidebar
    render_body
}

render_sidebar() {
    for i in "${!sidebar[@]}"; do
        printf '\e[%d;3f' "$((2*(i + 1)))"
        if (( i == selection )); then
            printf '\e[1m'  
        fi
        printf '%s\e[0m' "${sidebar[$i]}"
    done
    if [[ $PAGE_HAS_NEXT -eq 1 ]] || [[ $PAGE_HAS_PREV -eq 1 ]]; then
        offset=$((LINES - 2))
        printf '\e[%d;3f' "$offset"
        printf '%s %d\e[0m' "page:" "$((paginate+1))"
        printf '\e[%d;3f' "$((offset+1))"
        [[ $PAGE_HAS_PREV -eq 1 ]] && printf '' || printf '\e[1;30m'
        printf '%s\e[0m' "[H] <="
        printf '\e[%d;3f' "$((offset+2))"
        [[ $PAGE_HAS_NEXT -eq 1 ]] && printf '' || printf '\e[1;30m'
        printf '%s%s\e[0m' "$next_esc" "[L] =>"
    fi
}

render_body() {
    for i in "${!main_content[@]}"; do
        if (( (2 + i - scroll) > 0 && (2 + i - scroll) <= LINES )); then
            printf '\e[%d;16f%s' "$((2 + i - scroll))" "${main_content[$i]}"
        fi
    done
}

scroll_up() {
    if (( scroll > 0 )); then
        scroll=$(( scroll - 1))
        rerender
    fi
}

scroll_down() {
    content_length="${#main_content[@]}"
    scroll_limit=$(( content_length - LINES ))
    if (( scroll <= scroll_limit )); then
        scroll=$(( scroll + 1))
        rerender
    fi
}

page_prev() {
    if (( PAGE_HAS_PREV == 1 )); then
        nav "$page" $(( paginate - 1 )) "$selection"
    fi
}

page_next() {
    if (( PAGE_HAS_NEXT == 1 )); then
        nav "$page" $(( paginate + 1 )) "$selection"
    fi
}

nav() {
    page="$1"
    paginate=$2
    selection="$3"
    scroll=0

    if (( paginate > 0 )); then
        loadurl "$page.$paginate"
    else
        loadurl "$page"
    fi

    rerender
}

loadurl() {
    IFS=$'\n' read -d "" -ra main_content < <(curl "$base_url"/"$1".txt 2> /dev/null) 
    PAGE_FLAGS="${main_content[0]}"
    PAGE_HAS_PREV=$(((PAGE_FLAGS & MASK_HAS_PREV) == MASK_HAS_PREV))
    PAGE_HAS_NEXT=$(((PAGE_FLAGS & MASK_HAS_NEXT) == MASK_HAS_NEXT))
    main_content=("${main_content[@]:1}")
}

init() {
    page="$home_page"
    paginate=0
    selection=0

    loadurl "$page"
    printf '\e[?1049h'
    printf '\e[?25l'
}

reset() {
    printf '\e[?25h'
    printf '\e[?1049l'
}

clear_screen() {
    printf '\e[2J\e[H'
}

get_term_size() {
    IFS='[;' read -sp $'\e7\e[9999;9999H\e[6n\e8' -d R -rs _ LINES COLUMNS
}

cursor() {
    case "${1: -1}" in
        k) scroll_up;;
        j) scroll_down;;
        H) page_prev;;
        L) page_next;;
        a) nav "about" 0 "0";;
        b) nav "blog" 0 "1";;
        p) nav "projects" 0 "2";;
        c) nav "controls" 0 "3";;
        q) reset && exit 0;;
    esac
}

main() {
    init
    clear_screen
    get_term_size
    render

    trap 'reset' EXIT
    trap 'get_term_size' WINCH

    for ((;;)); { read -rs -n 1 key; cursor "$key"; }
}

main "$@"
