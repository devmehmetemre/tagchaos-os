import json
import os
import subprocess
import sys
import tarfile
import urllib.request


def ensure_dir(path):
  os.makedirs(path, exist_ok=True)


def pack_pkg(source_dir, manifest_path, output_tgh):
  with tarfile.open(output_tgh, "w:gz") as tar:
    tar.add(source_dir, arcname="app_files")
    tar.add(manifest_path, arcname="manifest.json")
  print(f"[+] Paket oluşturuldu: {output_tgh}")


def install_pkg(manifest_source, override_archive=None):
  if manifest_source.startswith("http"):
    req = urllib.request.urlopen(manifest_source)
    manifest = json.loads(req.read().decode("utf-8"))
  else:
    with open(manifest_source, "r", encoding="utf-8") as f:
      manifest = json.load(f)

  pkg_id = manifest["id"]
  apps_dir = os.path.expanduser(f"~/.tgh/apps/{pkg_id}")
  cache_dir = os.path.expanduser("~/.tgh/cache")
  ensure_dir(apps_dir)
  ensure_dir(cache_dir)

  archive_path = override_archive
  if not archive_path:
    pkg_url = manifest.get("url")
    if pkg_url and pkg_url.startswith("http"):
      archive_path = os.path.join(cache_dir, f"{pkg_id}.tgh")
      print(f"[*] İndiriliyor: {pkg_url}")
      urllib.request.urlretrieve(pkg_url, archive_path)
    else:
      raise ValueError("Geçerli bir arşiv adresi bulunamadı.")

  with tarfile.open(archive_path, "r:gz") as tar:
    tar.extractall(path=apps_dir)

  # Manifesti uygulama klasörüne sabitle
  with open(
      os.path.join(apps_dir, "manifest.json"), "w", encoding="utf-8"
  ) as f:
    json.dump(manifest, f, indent=2)

  print(f"[+] Kurulum başarılı: {pkg_id} -> {apps_dir}")


def run_pkg(pkg_id):
  apps_dir = os.path.expanduser(f"~/.tgh/apps/{pkg_id}")
  manifest_path = os.path.join(apps_dir, "manifest.json")

  if not os.path.exists(manifest_path):
    print(f"[!] Hata: {pkg_id} kurulu değil! Önce 'install' komutunu çalıştır.")
    sys.exit(1)

  with open(manifest_path, "r", encoding="utf-8") as f:
    manifest = json.load(f)

  target = manifest.get("target", "native")
  exec_cmd = manifest.get("exec", "")

  # Uygulama dosya dizinine geç
  os.chdir(os.path.join(apps_dir, "app_files"))

  print(f"[*] Başlatılıyor: {manifest.get('name', pkg_id)} (Mod: {target})")

  if target == "wine" or exec_cmd.lower().endswith(".exe"):
    full_cmd = f"wine {exec_cmd}" if not exec_cmd.startswith("wine ") else exec_cmd
    print(f"[*] Wine/Proton katmanı tetikleniyor: {full_cmd}")
    res = subprocess.run(full_cmd, shell=True)
    if res.returncode != 0:
      print("[!] Wine çalıştırma hatası veya sisteminde wine/exe yüklü değil.")
  else:
    subprocess.run(exec_cmd, shell=True)


def demo():
  print("=== TAGCHAOS OS: Uçtan Uca Demo Başlıyor ===")
  demo_src = os.path.expanduser("~/.tgh/demo_src")
  ensure_dir(demo_src)

  # Örnek uygulama dosyası yazalım
  with open(os.path.join(demo_src, "main.py"), "w", encoding="utf-8") as f:
    f.write('print("Merhaba! TAGCHAOS OS native uygulama katmanındasın.")\n')

  manifest = {
      "id": "com.tagchaos.hellodemo",
      "name": "TAG Hello App",
      "target": "native",
      "exec": "python main.py",
  }
  manifest_path = os.path.expanduser("~/.tgh/demo_manifest.json")
  with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)

  tgh_out = os.path.expanduser("~/.tgh/demo.tgh")
  pack_pkg(demo_src, manifest_path, tgh_out)

  # Kur ve Çalıştır
  install_pkg(manifest_path, override_archive=tgh_out)
  run_pkg("com.tagchaos.hellodemo")
  print("=== Demo Tamamlandı! ===")


if __name__ == "__main__":
  if len(sys.argv) < 2:
    print("Kullanım Şekilleri:")
    print("  python tghpm.py demo")
    print("  python tghpm.py install <json_dosyasi>")
    print("  python tghpm.py run <paket_id>")
    sys.exit(1)

  cmd = sys.argv[1]
  if cmd == "demo":
    demo()
  elif cmd == "install" and len(sys.argv) >= 3:
    install_pkg(sys.argv[2])
  elif cmd == "run" and len(sys.argv) >= 3:
    run_pkg(sys.argv[2])
  else:
    print("[!] Yanlış komut kullanımı.")