"""
ARGOS - Verificacion del ambiente Docker de testeo Bronze (OCR/PDF)
Replica los mismos chequeos realizados en el cluster argos-dev-bronze-testeo.
"""
import sys
import platform

def main():
    print("=" * 70)
    print(" ARGOS - Verificacion de ambiente (Docker) - Bronze OCR/PDF")
    print("=" * 70)

    print(f"[OK] Python version: {platform.python_version()}")

    try:
        import pytesseract
        version = pytesseract.get_tesseract_version()
        langs = pytesseract.get_languages(config="")
        print(f"[OK] Tesseract version: {version}")
        print(f"[OK] Idiomas disponibles: {', '.join(langs)}")
    except Exception as e:
        print(f"[ERROR] Tesseract/pytesseract: {e}")
        sys.exit(1)

    try:
        import pymupdf  # PyMuPDF
        print(f"[OK] PyMuPDF (pymupdf) version: {pymupdf.__version__}")
    except Exception as e:
        print(f"[ERROR] PyMuPDF: {e}")
        
        sys.exit(1)

    print("-" * 70)
    print(" Ambiente verificado correctamente.")
    print(" Monta un PDF de prueba en /workspace y corre tu script de OCR.")
    print("-" * 70)


if __name__ == "__main__":
    main()
