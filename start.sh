#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/render/project/src"
DATA="/data"
cd "$BASE"

echo "==> Preparando DISCO persistente en $DATA ..."

# 1) Carpetas persistentes
mkdir -p "$DATA/DB" "$DATA/usuarios" "$DATA/CAJA" "$DATA/REINTEGROS" "$DATA/logs" "$DATA/EXPORTS"

# 2) Sembrar DB XMLs la primera vez
if [ -z "$(ls -A "$DATA/DB" 2>/dev/null)" ]; then
  echo "Sembrando XML de static/db -> /data/DB ..."
  cp -n static/db/*.xml "$DATA/DB/" 2>/dev/null || true
fi

# 3) usuarios.xml persistente
if [ ! -f "$DATA/usuarios/usuarios.xml" ]; then
  if [ -f static/db/usuarios.xml ]; then
    cp static/db/usuarios.xml "$DATA/usuarios/usuarios.xml"
  else
    cat > "$DATA/usuarios/usuarios.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<usuarios>
  <usuario>
    <nombre>ADMIN</nombre>
    <clave>admin</clave>
    <rol>Super Administrador</rol>
    <email>admin@example.com</email>
    <estado>activo</estado>
    <avatar>avatar-male.png</avatar>
  </usuario>
</usuarios>
EOF
  fi
fi

# 4) caja.xml persistente
if [ ! -f "$DATA/CAJA/caja.xml" ]; then
  cat > "$DATA/CAJA/caja.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<caja>
  <dia fecha="$(date +%Y-%m-%d)">
    <configuracion>
      <valor_boleto>1.00</valor_boleto>
      <comision_vendedor>0.30</comision_vendedor>
      <comision_extra_meta>0</comision_extra_meta>
      <meta_boletos>0</meta_boletos>
    </configuracion>
  </dia>
</caja>
EOF
fi

# 5) Logs persistentes
mkdir -p instance/gl_bingo
rm -rf instance/gl_bingo/logs || true
ln -sfn "$DATA/logs" instance/gl_bingo/logs
[ -f "$DATA/logs/impresiones.xml" ] || echo "<impresiones/>" > "$DATA/logs/impresiones.xml"

# 6) static/db apunta al DISCO
rm -rf static/db || true
mkdir -p static/db
for f in "$DATA/DB"/*.xml; do
  [ -e "$f" ] || continue
  ln -sfn "$f" "static/db/$(basename "$f")"
done
ln -sfn "$DATA/usuarios/usuarios.xml" static/db/usuarios.xml
ln -sfn "$DATA/CAJA/caja.xml"      static/db/caja.xml

# 7) Compatibilidad DATA/...
mkdir -p DATA
for d in DB usuarios CAJA REINTEGROS logs; do
  rm -rf "DATA/$d" || true
  ln -sfn "$DATA/$d" "DATA/$d"
done

echo "==> Persistencia lista. Iniciando Gunicorn..."
exec gunicorn app:app --bind 0.0.0.0:${PORT:-10000} --workers 2 --timeout 120
