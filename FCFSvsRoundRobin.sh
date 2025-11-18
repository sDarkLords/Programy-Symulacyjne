#!/bin/bash

####################
#Description: Funkcja zapisująca wyniki symulacji do pliku
#Globals: None
#Arguments $1-nazwa pliku wyjściowego
#	   $2-treść do zapisania
#Outputs: Plik z wynikami symulacji
#Returns: 0 jeśli sukces, 1 jeśli błąd zapisu
####################
function save_to_file {
    local output_file=$1
    local content=$2

    if echo "$content" > "$output_file"; then
        echo "Wyniki zapisano w $output_file"
        return 0
    else
        echo "Błąd podczas zapisywania do pliku $output_file" >&2
        return 1
    fi
}

####################
#Description: Funkcja generująca dane procesów (nazwy i czasu wykonania)
#Globals: PROCESS_NAMES;PROCESS_BURSTS
#Arguments: $1-liczba procesów do wygenerowania
#Outputs: Plik "process_data.txt" z wygenerowanymi danymi
#Returns: 0 jeśli sukces, non-zero jeśli wystąpił błąd
####################
function generate_process_data {
    local process_count=$1 # Liczba procesów przekazana jako argument
    local output_file="process_data.txt" # Nazwa pliku wyjściowego
    local -a processes # Tablica na nazwy procesów 
    local -a bursts # Tablica na czasy wykonania 

    echo "Generowanie $process_count procesów"
    
    #Generowanie nazw procesów (P1,P2,...) i losowych czasów wykonania 
    for ((i=1; i<=$process_count; i++)); do
        processes[$i-1]="P$i" # Nazwa procesu
        bursts[$i-1]=$((RANDOM % 10 + 1))  # Losowy czas wykonania 
    done

    # Zapis danych do pliku
    echo "Procesy: ${processes[@]}" > $output_file # Zapis nazw procesów 
    echo "Czasy_wykonania: ${bursts[@]}" >> $output_file # Zapis czasów wykonania 

    echo "Dane procesów zapisano w $output_file"
    echo ""

    # Przypisanie danych do zmiennych globalnych 
    PROCESS_NAMES=("${processes[@]}") # Globalna tablica nazw procesów 
    PROCESS_BURSTS=("${bursts[@]}") # Globalna tablica czasów wykonania
}

####################
#Description: Funkcja pobierająca od użytkownika liczbę procesów (minimum 1)
#Globals: None
#Arguments $1-liczba procesów podawana przez użytkownika 
#Outputs: Liczba procesów
#Returns: 0 jeśli sukces, 1 jeśli liczba procesów jest nieprawidłowa
####################
function read_process_count {
    while true; do # Nieskończona pętla (aż do poprawnego wprowadzenia)
        read -p "Podaj liczbę procesów (minimum 1): " process_count
        # Sprawdzenia poprawności danych 
        if [[ $process_count =~ ^[1-9][0-9]*$ ]]; then
            break # Wyjście z pętli jeśli poprawna wartość
        else
            echo "Nieprawidłowa wartość. Podaj liczbę całkowitą większą od 0."
        fi
    done
}

####################
#Description: Funkcja symulująca algorytm FCFS (First Come First Served)
#Globals: None 
#Arguments: $1-referencja do tablicy nazw procesów (indirect reference)
#	    $2-referencja do tablicy czasów wykonania (indirect reference)
#Outputs: Tabela z wynikami dla każdego procesu
#	  Średnie czasy oczekiwania i przetwarzania 
#Returns: 0 zawsze sukces
####################
function fcfs {
    local p=("${!1}")    # Tablica nazw procesów
    local bt=("${!2}")   # Tablica czasów wykonania
    
    local time=0 # Aktualny czas systemowy
    local total_waiting=0 # Suma czasów oczekiwania
    local total_turnaround=0 # Suma czasów przetwarzania
    local count=${#p[@]} # Liczba procesów
    
    # Nagłówek tabeli wyników
    echo "FCFS Scheduling:"
    echo "Process | Burst | Waiting | Turnaround"
    echo "--------|-------|---------|-----------"
    
    # Pętla obliczająca czasy dla każdego procesu
    for ((i=0; i<$count; i++)); do
        local waiting=$time # Czas oczekiwania=aktualny czas systemowy
        local turnaround=$((waiting + bt[i])) # Czas przetwarzania=oczekiwanie+wykonanie
        
        # Wyświetlenia wiersza wyników
        printf "%7s | %5d | %7d | %10d\n" "${p[i]}" "${bt[i]}" "$waiting" "$turnaround"
        
        # Aktualizacja sum
        total_waiting=$((total_waiting + waiting))
        total_turnaround=$((total_turnaround + turnaround))
        time=$((time + bt[i])) # Inkrementacja czasu systemowego
    done
    
    # Obliczenie średnich czasów
    local avg_waiting=$((total_waiting / count))
    local avg_turnaround=$((total_turnaround / count))
    
    # Wyświetlenie średnich
    echo "Average Waiting Time: $avg_waiting"
    echo "Average Turnaround Time: $avg_turnaround"
}

####################
#Description: Funkcja symuująca algorytm Round Robin
#Globals: None
#Arguments: $1-referencja do tablicy nazw procesów (indirect reference)
#	   $2-referencja do tablicy czasów wykonania (indirect reference)
#	   $3-wartość kwantu czasu (quantum)
#Outputs: Szczegóły wykonania (dla <= 20 procesów)
#	  Podsumowanie czasów oczekiwania i przetwarzania
#Returns: 0 zawsze sukces
####################
function round_robin {
    local p=("${!1}")    # Tablica nazw procesów
    local bt=("${!2}")   # Tablica czasów wykonania
    local q=$3           # Quantum
    
    local count=${#p[@]} # Liczba procesów
    local remaining=("${bt[@]}") # Tablica pozostałych czasów wykonania
    local waiting=() # Tablica czasów oczekiwania
    local turnaround=() # Tablica czasów przetwarzania
    local time=0 # Aktualny czas systemowy
    local completed=0 # Liczba zakończonych procesów
    
    # Inicjalizacja tablic waiting i turnaround zerami
    for ((i=0; i<$count; i++)); do
        waiting[$i]=0
        turnaround[$i]=0
    done
    
    echo "Round Robin Scheduling (Quantum: $q):"
    
    # Skrócony widok dla dużej liczby procesów
    if [ $count -gt 20 ]; then
        echo "Zbyt wiele procesów do wyświetlenia szczegółów. Pokazuję tylko podsumowanie."
    else
    	# Formatowana tabela przebiedu symulacji
        echo "Time | Process | Remaining"
        echo "-----|---------|----------"
    fi
    
    # Główna pętla symulacji
    # Działa dopóki wszystkie procesy nie zostaną wykonane
    while [ $completed -lt $count ]; do
    	# Iteracja przez wszytkie procesy w kolejce
        for ((i=0; i<$count; i++)); do
            # Sprawdzenie czy proces jeszcze potrzebuje czasu CPU
            if [ ${remaining[$i]} -gt 0 ]; then
            	# Przypadek 1: Proces potrzebuje więcej czasu niż quantum
                if [ ${remaining[$i]} -gt $q ]; then
                    # Wyświetlanie szczegółów (tylko dla <= 20 procesów)
                    if [ $count -le 20 ]; then 
                        echo "$time | ${p[$i]} | ${remaining[$i]} -> $((remaining[i] - q))"
                    fi
                    
                    # Aktualizacja czasu symulacji i pozostałego czasu procesu
                    time=$((time + q))
                    remaining[$i]=$((remaining[i] - q))
                # Przypadek 2: Proces kończy się w tym kwancie czasu
                else
                    if [ $count -le 20 ]; then
                        echo "$time | ${p[$i]} | ${remaining[$i]} -> 0"
                    fi
                    
                    # Aktualizacja czasu symulacji
                    time=$((time + remaining[$i]))
                    # Zapamiętanie czasu przetwarzania (turnaround time)
                    turnaround[$i]=$time
                    # Oznaczenie procesu jako zakończonego
                    remaining[$i]=0
                    completed=$((completed + 1))
                fi
                
                # Aktualizacja czasu oczekiwania dla innych procesów
                for ((j=0; j<$count; j++)); do
                    if [ $j -ne $i ] && [ ${remaining[$j]} -gt 0 ]; then
                    	# Dodanie czasu wykonania bieżącego procesu (q lub mniej)
                        waiting[$j]=$((waiting[j] + (remaining[$i] > q ? q : remaining[$i])))
                    fi
                done
            fi
        done
    done
    
    # Obliczanie i wyświetlanie podsumowania
    local total_waiting=0
    local total_turnaround=0
    
    echo ""
    echo "Process | Waiting | Turnaround"
    echo "--------|---------|-----------"
    
    # Dla >50 procesów skrypt pokazuje tylko podsumowanie
    if [ $count -gt 50 ]; then
        echo "[... pokazano pierwsze i ostatnie 5 procesów ...]"
        local show_count=$((count < 10 ? count : 5))
        
        # Wyświetl pierwsze 5 procesów
        for ((i=0; i<$show_count; i++)); do
            printf "%7s | %7d | %10d\n" "${p[i]}" "${waiting[i]}" "${turnaround[i]}"
            total_waiting=$((total_waiting + waiting[i]))
            total_turnaround=$((total_turnaround + turnaround[i]))
        done
        
        echo "[... pominięto $((count - 2*show_count)) procesów ...]"
        
        # Wyświetl ostatnie 5 procesów
        for ((i=$((count-show_count)); i<$count; i++)); do
            printf "%7s | %7d | %10d\n" "${p[i]}" "${waiting[i]}" "${turnaround[i]}"
            total_waiting=$((total_waiting + waiting[i]))
            total_turnaround=$((total_turnaround + turnaround[i]))
        done
    else
        # Wyświetl wszytkie procesy
        for ((i=0; i<$count; i++)); do
            printf "%7s | %7d | %10d\n" "${p[i]}" "${waiting[i]}" "${turnaround[i]}"
            total_waiting=$((total_waiting + waiting[i]))
            total_turnaround=$((total_turnaround + turnaround[i]))
        done
    fi
    
    # Obliczenie średnich czasów
    local avg_waiting=$((total_waiting / count))
    local avg_turnaround=$((total_turnaround / count))
    
    # Wyświetlenie podsumowania
    echo ""
    echo "Average Waiting Time: $avg_waiting"
    echo "Average Turnaround Time: $avg_turnaround"
    echo "Total Processes: $count"
}
####################
#Description: Funkcja porównująca działanie algorytmów FCFS i Round Robin
#Globals: PROCESS_NAMES;PROCESS_BURSTS
#Arguments: Brak bezpośrednich argumentów (korzysta z globalnych zmiennych)
#Outputs: Pełne wyniki symulacji FCFS:
#			Dla każdego procesu: nazwa, czas wykonania, czas oczekiwania, czas przetwarzania)
#			Średnie czasy oczekiwania i przetwarzania
#	  Pełne wyniki symulacji Round Robin:
#			Szczegóły wykonania (dla <=20 procesów)
#			Czasy oczekiwania i przetwarzania procesów
#			Średnie czasy i podsumowania
#Returns: 0 zawsze sukces
####################
function compare_schedulers {
    # Przygotowanie danych wejściowych
    local process_names=("${PROCESS_NAMES[@]}") # Kopiowanie globalnej tablicy nazw procesów
    local process_bursts=("${PROCESS_BURSTS[@]}") # Kopiowanie globalnej tablicy czasów wykonania
    local quantum=5 # Ustalenie wartości kwantu czasu dla Round Robin
    
    # Wyświetlenie nagłówka porównania
    echo ""
    echo "=== Porównanie FCFS i Round Robin ==="
    echo "Liczba procesów: ${#process_names[@]}"
    
    # Warunkowe wyświetlenie szczegółów procesów (tylko dla <=20 rocesów)
    if [ ${#process_names[@]} -le 20 ]; then
        echo "Procesy: ${process_names[@]}"
        echo "Czasy wykonania: ${process_bursts[@]}"
    else
        echo "[Zbyt wiele procesów do wyświetlenia listy]"
    fi
    echo ""
    
    # Wykonanie symulacji FCFS
    echo "== FCFS =="
    fcfs process_names[@] process_bursts[@] # Wywołanie funkcji FCFS z przekazaniem tablic
    
    # Wykonanie symulacji Round Robin
    echo ""
    echo "== Round Robin (quantum=$quantum) =="
    round_robin process_names[@] process_bursts[@] $quantum 
}

clear # Czyszczenie ekranu terminala przd uruchomieniem
echo "=== Symulator algorytmów planowania procesów ===" # Nagłówek programu

# Pobranie danych od użytkownika 
read_process_count

# Generowanie danych procesów
generate_process_data $process_count

# Wykonanie symulacji i przechwycenie wyników
simulation_results=$(
    echo "=== Wyniki symulacji ==="
    echo "Liczba procesów: $process_count"
    echo ""
    compare_schedulers
)

# Wyświetlenie wyników na ekranie
echo "$simulation_results"

# Zapis wyników do pliku
save_to_file "simulation_results.txt" "$simulation_results"


# Komikat końcowy
echo ""
echo "Symulacja zakończona."
