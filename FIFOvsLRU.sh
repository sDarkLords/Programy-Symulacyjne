#!/bin/bash

####################
#Description: Funkcja zapisująca wyniki symulacji do pliku
#Globals: None
#Arguments: $1-nazwa pliku wyjściowego
#	    $2-zawartość do zapisania
#Outputs: Plik z wynikami symulacji
#Returns: 0 jeśli sukces, 1 jeśli błąd zapisu
####################
function save_to_file {
    local filename=$1 # Zmienna na nazwę pliku
    local content=$2 # Zmienna na zawartość
    
    # Próba zapisu do pliku
    if echo "$content" > "$filename"; then
        echo "Zapisano dane do pliku: $filename"
        return 0  # Kod sukcesu
    else
        echo "Błąd podczas zapisywania" >&2  # Komunikat na stderr
        return 1  # Kod błędu
    fi
}

####################
#Description: Funkcja generująca losową sekwencję odwołań do stron
#Globals: None
#Arguments: $1-liczba odwołań do wygenerowania
#	    $2-maksymalny numer strony
#Outputs: Tablica z losowymi numerami stron
#Returns: 0 jeśli sukces, 1 jeśli wystąpił błąd
####################
function generate_references {
    local count=$1 # Liczba odwołań do wygenerowania
    local max_page=$2 # Maksymalny numer strony
    local -a references=() # Tablica na wyniki 
    
    # Generowanie losowych numerów stron
    for ((i=0; i<count; i++)); do
        references[$i]=$((RANDOM % (max_page + 1))) # Losow wartość 0-max_page 
    done
    
    echo "${references[@]}" # Zwróć tablicę jako string 
}

####################
#Description: Funkcja pobierająca od użytkownika liczbę odwołań (minimum 1)
#Globals: None
#Arguments $1-liczba odwołań podawana przez użytkownika 
#Outputs: Liczba odwołań
#Returns: 0 jeśli sukces, 1 jeśli liczba odwołań jest nieprawidłowa
####################
function read_ref_count {
    while true; do
        read -p "Podaj liczbę odwołań (minimum 1): " ref_count
        # Sprawdzenie czy to dodatnia liczba całkowita
        if [[ $ref_count =~ ^[1-9][0-9]*$ ]]; then
            break
        else
            echo "Nieprawidłowa wartość. Podaj liczbę całkowitą większą od 0."
        fi
    done
}

####################
#Description: Funkcja pobierająca od użytkownika zakres numerów stron (minimum 1)
#Globals: None
#Arguments $1-zakres podawany przez użytkownika 
#Outputs: Zakres numerów stron
#Returns: 0 jeśli sukces, 1 jeśli zakres jest nieprawidłowy
####################
function read_max_page {
    while true; do
        read -p "Podaj maksymalny numer strony (minimum 1): " max_page
        # Sprawdzenie czy to dodatnia liczba całkowita
        if [[ $max_page =~ ^[1-9][0-9]*$ ]]; then
            break
        else
            echo "Nieprawidłowa wartość. Podaj liczbę całkowitą większą od 0."
        fi
    done
}

####################
#Description: Funkcja pobierająca od użytkownika rozmiar pamięci fizycznej (minimum 1)
#Globals: None
#Arguments $1-rozmiar pamięci podawany przez użytkownika 
#Outputs: Rozmiar pamięci fizycznej
#Returns: 0 jeśli sukces, 1 jeśli rozmiar jest nieprawidłowy
####################
function read_frame_count {
    while true; do
        read -p "Podaj liczbę ramek (minimum 1): " frame_count
        # Sprawdzenie czy to dodatnia liczba całkowita
        if [[ $frame_count =~ ^[1-9][0-9]*$ ]]; then
            break
        else
            echo "Nieprawidłowa wartość. Podaj liczbę całkowitą większą od 0."
        fi
    done
}

####################
#Description: Funkcja obliczająca efktywność pamięci podręcznej
#Globals: None
#Arguments $1-liczba błędów strony
#	   $2-całkowita liczba odwałań
#Outputs: Współczynnik trafień (hit ratio) i nietrafień (miss ratio)
#Returns: 0 zawsze sukces
####################
function calculate_cache_efficiency {
    local faults=$1
    local total=$2
    
    # Zabezpieczenie przed dzieleniem przez zero
    if [ "$total" -eq 0 ]; then
        echo "Błąd: Brak odwołań do stron (total=0)"
        return 1
    fi
    
    local hits=$((total - faults))
    
    # Sprawdzenie czy bc jest dostępne
    if ! command -v bc &> /dev/null; then
        echo "Uwaga: 'bc' nie jest zainstalowane, pokazuję tylko wartości bezwzględne"
        echo "  - Trafienia (hits): $hits/$total"
        echo "  - Błędy (misses): $faults/$total"
        return 0
    fi
    
    local hit_ratio=$(echo "scale=2; $hits*100/$total" | bc)
    local miss_ratio=$(echo "scale=2; $faults*100/$total" | bc)
    
    echo "Efektywność pamięci podręcznej:"
    echo "  - Trafienia (hits): $hits/$total ($hit_ratio%)"
    echo "  - Błędy (misses): $faults/$total ($miss_ratio%)"
    echo "  - Współczynnik trafień (hit ratio): $hit_ratio%"
}

####################
#Description: Funkcja symulująca algorytm zastępowania stron FIFO (First In First Out)
#Globals: None
#Arguments: $1-referencja do tablicy odwołań (indirect reference)
#	    $2-liczba dostępnych ramek
#Outputs: Tabela z przebiegiem symulacji
#	  Łączna liczba błędów strony
#Returns: 0 zawsze sukces
####################
function fifo_page_replacement {
    # Deklaracja i inicjalizacja zmiennych
    local -a references=("${!1}") # Tablica odwołań do stron 
    local frame_count=$2 # Maksymalna liczba stron w pamięci
    
    local -a frames=() # Tablica przechowująca bieżące strony w pamięci
    local faults=0 # Licznik błędów strony 
    local -a queue=() # Kolejka FIFO do śledzenia kolejności ładowania stron
    
    # Nagłówek tabeli wyników
    echo "FIFO Page Replacement:"
    echo "Reference | Frames | Fault"
    echo "----------|--------|------"
    
    # Główna pętla przetwarzająca każde odwołanie
    for ref in "${references[@]}"; do
        local fault=0 # Flaga błędu strony 
        local found=0 # Flaga obecności strony w pamięci
        
        # Sprawdzenie czy strona jest już w pamięci
        for frame in "${frames[@]}"; do
            if [ "$frame" -eq "$ref" ]; then
                found=1 # Strona znaleziona w pamięci
                break
            fi
        done
        
        # Obsługa przypadku gdy strony nie ma w pamięci
        if [ $found -eq 0 ]; then
            fault=1 # Odznaczamy wystąpienie błędu strony
            faults=$((faults + 1)) # Inkrementacja licznik błędów
            
            # Spradzenia czy są wolne ramki
            if [ ${#frames[@]} -lt $frame_count ]; then
                # Dodanie strony do pamięci i kolejki
                frames+=("$ref")
                queue+=("$ref")
            else
                # Zastępowanie strony-algorytm FIFO
                local to_replace=${queue[0]} # Pobranie najstarszej strony z kolejki
                queue=("${queue[@]:1}") # Usunięcie jej z kolejki
                
                # Znalezienie i zastąpienie strony w tablicy frames
                for i in "${!frames[@]}"; do
                    if [ "${frames[$i]}" -eq "$to_replace" ]; then
                        frames[$i]=$ref # Zastąpienie strony
                        break
                    fi
                done
                
                queue+=("$ref") # Dodanie nowej strony na koniec kolejki
            fi
        fi
        
        # Wyświetlenie bieżącego stanu w formacie tabeli 
        printf "%9d | [" "$ref" # Numer referencyjny strony
        # Aktualna zawartość ramek
        for frame in "${frames[@]}"; do
            printf "%d " "$frame"
        done
        printf "] | %d\n" "$fault" # Informacja o błędzie strony
    done
    
    # Wyświetlenie podsumowania
    echo "Total Page Faults: $faults"
    calculate_cache_efficiency $faults ${#references[@]}
}

####################
#Description: Funkcja symuująca algorytm zastępowania stron LRU (Least Recently Used)
#Globals: None
#Arguments $1-nazwana referencja do tablicy odwołań
#	   $2-liczba dostępnych ramek
#Outputs: Tabela z przebiegiem symulacji
#	  Łączna liczba błędów strony
#Returns: 0 zawsze sukces
####################
function lru_page_replacement {
    # Deklaracja i inicjalizacja zmiennych
    local -n ref_array=$1 # Referencja do tablicy odwołań 
    local frame_count=$2 # Maksymalna liczba stron w pamięci
    
    local frames=() # Tablica przechowująca bieżące strony w pamięci
    local faults=0 # Licznik błędów strony 
    local last_used=() # Tablica przechowująca czas ostatniego użycia każdej strony
    
    # Nagłówek wyjścia
    echo "LRU Page Replacement:"
    echo "Reference | Frames | Fault"
    echo "----------|--------|------"
    
    # Główna pętla przetwarzająca każde odwołanie
    for ref in "${ref_array[@]}"; do
        local fault=0 # Flaga błędu strony 
        local found=0 # Flaga obecności strony w pamięci
        
	# Sprawdzenia czy strona jeat już w pamięci
        for i in "${!frames[@]}"; do
            if [ "${frames[$i]}" -eq "$ref" ]; then
                found=1
                #Aktualizacja czasu ostatniego użycia strony (bieżący czas w nanosekundach)
                last_used[$i]=$(date +%s%N)
                break
            fi
        done

	# Obsługa przypadku gdy strony nie ma w pamięci
        if [ $found -eq 0 ]; then
            fault=1 # Odznaczamy wystąpienie błędu strony
            ((faults++)) # Inkrementacja licznik błędów
	    
	    # Sprawdzenie czy są wolne ranki
            if [ ${#frames[@]} -lt "$frame_count" ]; then
                # Dodanie nowej strony do pamięci
                frames+=("$ref")
                # Zapisanie czasu pierwszego użycia
                last_used+=($(date +%s%N))
            else
            	# Znalezienie strony do zastąpienia (najstarszy czas ostatniego użycia)
                local oldest=0 # Indeks domyślnie pierwszej strony
                
                # Przeszukanie tablicy last_used w poszukiwaniu najstarszego czasu
                for i in "${!last_used[@]}"; do
                    if [ "${last_used[$i]}" -lt "${last_used[$oldest]}" ]; then
                        oldest=$i # Znaleziono starszy czas
                    fi
                done

		# Zastąpienie najrzadziej używanej strony
                frames[$oldest]=$ref
                # Aktualizacja czasu ostatniego użycia dla nowej strony
                last_used[$oldest]=$(date +%s%N)
            fi
        fi

	# Wyświetlenia bieżącego stanu w formacie tabeli
        printf "%9d | [" "$ref" # Numer referencyjny strony
        # Aktualna zawartość ramek
        for frame in "${frames[@]}"; do 
            printf "%d " "$frame"
        done
        printf "] | %d\n" "$fault" # Informacja o błędzie strony
    done
    
    # Wyświetlenie podsumowania
    echo "Total Page Faults: $faults"
    calculate_cache_efficiency $faults ${#ref_array[@]}
}

# Główna część skryptu

clear # Czyszczenie ekranu terminala przd uruchomieniem
# Wyświetlenie nagłówka programu
echo "=== Porównanie algorytmów FIFO i LRU ==="

# Pobranie danych od użytkownika 
read_ref_count # Liczba odwołań do zasymulowania
read_max_page # Zakres numerów stron
read_frame_count # Rozmiar pamięci fizycznej

# Generowanie sekwencji odwołań
references=($(generate_references $ref_count $max_page))

# Zapis parametrów wejściowych do pliku
input_data="=== Parametry wejściowe ===
Liczba odwołań: $ref_count
Maksymalny numer strony: $max_page
Liczba ramek: $frame_count
Sekwencja odwołań: ${references[*]}
"
save_to_file "input_parameters.txt" "$input_data"

# Wyświetlenie wygenerowanej sekwencji 
echo ""
echo "Wygenerowane odwołania: ${references[*]}"
echo ""

# Wykonanie symulacji FIFO
fifo_output=$(fifo_page_replacement references[@] $frame_count)

echo ""

# Wykonanie symulacji LRU
lru_output=$(lru_page_replacement references $frame_count)

# Przygotowanie i zapis pełnego raportu
report="=== Podsumowanie ===
$input_data

=== Wyniki FIFO ===
$fifo_output

=== Wyniki LRU ===
$lru_output
"

save_to_file "simulation_report.txt" "$report"

# Wyświetlenie pełnego raportu na standardowe wyjście
echo ""
echo "$report"
