import os
import re

def napraw_playstate():
    sciezka_pliku = os.path.join("source", "PlayState.hx")
    
    if not os.path.exists(sciezka_pliku):
        print(f"❌ Nie znaleziono pliku pod ścieżką: {sciezka_pliku}")
        print("Upewnij się, że uruchamiasz ten skrypt z głównego katalogu swojego silnika!")
        return

    print(f"🔄 Wczytywanie pliku {sciezka_pliku}...")
    with open(sciezka_pliku, "r", encoding="utf-8") as f:
        kod = f.read()

    # Szukamy starej definicji tablicy ratingsData (niezależnie od formatowania i białych znaków)
    wzorzec_stary = r"(public\s+var\s+ratingsData\s*:\s*Array<Rating>\s*=\s*\[\s*\{[\s\S]*?\}\s*\]\s*;)"
    
    # Nowa, ściśle typowana tablica zgodna z HaxeFlixel 5.5.0
    nowy_kod_tablicy = (
        "public var ratingsData:Array<Rating> = [\n"
        "        new Rating('sick'),\n"
        "        new Rating('good'),\n"
        "        new Rating('bad'),\n"
        "        new Rating('shit')\n"
        "    ];"
    )

    # Sprawdzamy czy w pliku jest wymagany import backend.Rating
    if "import backend.Rating;" not in kod:
        print("📦 Dodawanie brakującego importu backend.Rating...")
        # Wstrzykujemy import zaraz po deklaracji pakietu
        kod = re.sub(r"(package\s+source\s*;)", r"\1\nimport backend.Rating;", kod)

    # Podmieniamy strukturę anonimową na konstruktory
    if re.search(wzorzec_stary, kod):
        zmieniony_kod = re.sub(wzorzec_stary, nowy_kod_tablicy, kod)
        
        with open(sciezka_pliku, "w", encoding="utf-8") as f:
            f.write(zmieniony_kod)
        print("✅ Pomyślnie naprawiono typowanie Array<Rating> w PlayState.hx!")
    else:
        # Zabezpieczenie na wypadek, gdyby tablica była sformatowana inaczej
        print("⚠️ Nie udało się dopasować dokładnego wzorca obiektów anonimowych za pomocą wyrażenia regularnego.")
        print("Zastępowanie uproszczone: szukanie słowa kluczowego 'ratingsData'...")
        
        # Próba prostszego dopasowania od 'public var ratingsData' do domykającego średnika
        wzorzec_prosty = r"public\s+var\s+ratingsData\s*:\s*Array<Rating>[\s\S]*?\]\s*;"
        if re.search(wzorzec_prosty, kod):
            zmieniony_kod = re.sub(wzorzec_prosty, nowy_kod_tablicy, kod)
            with open(sciezka_pliku, "w", encoding="utf-8") as f:
                f.write(zmieniony_kod)
            print("✅ Pomyślnie naprawiono ratingsData przy użyciu zapasowego wzorca!")
        else:
            print("❌ Nie znaleziono zmiennej ratingsData. Możliwe, że została już zmodyfikowana ręcznie.")

if __name__ == "__main__":
    napraw_playstate()