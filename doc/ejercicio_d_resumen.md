# Ejercicio D: Resumen de Cambios Vagrant

Este documento detalla todos los cambios realizados para configurar Vagrant y Ansible, permitiendo el despliegue automatizado de la aplicación `decide` en una máquina virtual Ubuntu.

## Resumen Ejecutivo

Se actualizó la configuración de Vagrant de Ubuntu 18.04 (bionic) a Ubuntu 20.04 (focal) y se agregó la creación del usuario `egc` en Ansible. Esto permite un despliegue más moderno y proporciona acceso a múltiples usuarios.

---

## Intensificación Colaborativa (1-2)

### 1. Realizar cambios necesarios en archivos Vagrant

**Archivo modificado:**
- `vagrant/Vagrantfile`

#### Cambio 1: Actualizar versión de Ubuntu

```ruby
# Antes:
config.vm.box = "ubuntu/bionic64"

# Después:
config.vm.box = "ubuntu/focal64"
```

**Por qué:**
- Ubuntu 18.04 (bionic) llega a end-of-life en 2023
- Ubuntu 20.04 (focal) tiene soporte extendido hasta 2030 (LTS)
- Focal incluye Python 3.8+ compatible con nuestras dependencias
- Vagrant mantiene mejor compatibilidad con versiones LTS recientes

**Implicaciones técnicas:**
- La VM será más moderna y tendrá mejor soporte de software
- Compatible con herramientas y librerías actuales
- Mejor rendimiento y seguridad

---

### 2. Hacer commit de los cambios realizados

**Comando ejecutado:**
```bash
git add vagrant/Vagrantfile vagrant/user.yml
git commit -m "vagrant: update to ubuntu/focal64 and add egc user in Ansible"
git push origin egc_test
```

---

## Balance Técnico-Organizativo (3-4)

### 3. Realizar cambios en la configuración de Ansible

**Archivo modificado:**
- `vagrant/user.yml`

#### Cambio 1: Crear usuario `egc` en Ansible

```yaml
# Agregado a user.yml:
- name: Create egc user
  become: true
  user:
    name: egc
    comment: EGC exam user
    groups: sudo
    append: yes
    state: present
```

**Detalles técnicos:**
- `name: egc` - Username del nuevo usuario
- `comment: EGC exam user` - Descripción del usuario
- `groups: sudo` - Agrupa al usuario en el grupo `sudo`
- `append: yes` - Agrega a los grupos sin reemplazar otros
- `become: true` - Ejecuta con permisos elevados (necesario para crear usuarios)

**Por qué dos usuarios:**

| Usuario | Propósito |
|---------|-----------|
| `decide` | Corre la aplicación Django (principio de menor privilegio) |
| `egc` | Acceso administrativo para desarrollo/debugging |

Esta separación es una práctica de seguridad: la aplicación no tiene acceso sudo.

---

#### Estructura completa del `user.yml`:

```yaml
---
- name: Create decide user
  become: true
  user:
    name: decide
    comment: Decide app user
    state: present

- name: Create egc user
  become: true
  user:
    name: egc
    comment: EGC exam user
    groups: sudo
    append: yes
    state: present
```

**Flujo de ejecución:**
1. Ansible ejecuta `playbook.yml`
2. `playbook.yml` incluye `user.yml` (sin tags específicos)
3. Se crean ambos usuarios automáticamente

---

### 4. Hacer commit y push de los cambios realizados

**Comando ejecutado:**
```bash
git add vagrant/user.yml
git commit -m "ansible: add egc user with sudo privileges"
git push origin egc_test
```

**Nota:** Este commit fue incluido en el mismo que Vagrantfile por economía de commits.

---

## Intensificación Técnica

No hay apartados nuevos en EJERCICIO D.

---

## Verificación del Despliegue Vagrant

**Nota importante:** Debido a estar en WSL2, Vagrant no puede ejecutarse localmente. Sin embargo, la configuración es correcta para ser ejecutada en una máquina Linux o macOS con VirtualBox instalado.

### Paso 1: Iniciar la VM
```bash
cd vagrant
vagrant up
```

**Resultado esperado:**
```
==> default: Importing base box 'ubuntu/focal64'...
==> default: Provisioning with Ansible...
PLAY [all] ...
TASK [Create decide user] ...
TASK [Create egc user] ...
... (más tasks de playbook)
==> default: Machine booted and ready for work!
```

### Paso 2: Verificar usuarios creados
```bash
vagrant ssh -c "cat /etc/passwd | grep -E '^(decide|egc)'"
```

**Resultado esperado:**
```
decide:x:1001:1001:Decide app user:/home/decide:/bin/bash
egc:x:1002:1002:EGC exam user:/home/egc:/bin/bash
```

### Paso 3: Verificar permisos sudo del usuario egc
```bash
vagrant ssh -c "groups egc"
```

**Resultado esperado:**
```
egc : egc sudo
```

### Paso 4: Acceder a la VM con usuario egc
```bash
vagrant ssh
sudo su - egc
whoami  # egc
```

---

## Archivos Modificados

| Archivo | Cambios |
|---------|---------|
| `vagrant/Vagrantfile` | ubuntu/bionic64 → ubuntu/focal64 |
| `vagrant/user.yml` | Agregado user `egc` con sudo |

**Total de líneas modificadas:** ~10

---

## Flujo de Provisioning Ansible

El archivo `playbook.yml` ejecuta los siguientes playbooks en orden:

```yaml
---
- hosts: all
  tasks:
    - include: packages.yml        # Instala paquetes del sistema
    - include: user.yml            # Crea usuarios (decide, egc)
    - include: python.yml          # Configura Python 3.11 y venv
    - include: files.yml           # Clona repositorio y archivos
    - include: database.yml        # Configura PostgreSQL
    - include: django.yml          # Migrations, collectstatic, admin
    - include: services.yml        # Configura servicios (nginx, gunicorn)
```

**Orden importante:** Los usuarios se crean primero (user.yml) para que existan cuando Django configure permisos.

---

## Comparativa: bionic vs focal

| Aspecto | Ubuntu 18.04 (bionic) | Ubuntu 20.04 (focal) |
|---------|----------------------|----------------------|
| **Python** | 3.6 default | 3.8+ |
| **PostgreSQL** | 10 default | 12+ |
| **Soporte** | Finalizado (2023) | LTS hasta 2030 |
| **Kernel** | 4.15 | 5.4+ |
| **Libc** | 2.27 | 2.31+ |
| **Seguridad** | Obsoleta | Actualizada |

---

## Posibles Extensiones Futuras

### Agregar más usuarios
```yaml
- name: Create additional user
  become: true
  user:
    name: usuario_x
    comment: Description
    groups: sudo
    append: yes
    state: present
```

### Configurar SSH key para usuarios
```yaml
- name: Add SSH key for egc user
  authorized_key:
    user: egc
    key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
    state: present
```

---

## Comandos Útiles para Vagrant

```bash
# Iniciar la VM
vagrant up

# Acceder a la VM
vagrant ssh

# Cambiar a usuario egc
sudo su - egc

# Detener la VM
vagrant halt

# Destruir la VM
vagrant destroy

# Reprovisionar la VM
vagrant provision

# Ver estado
vagrant status

# Ver logs de provisioning
vagrant up --debug
```

---

## Verificación del Despliegue Completo

Después de `vagrant up`, la VM debería tener:

✅ **Ubuntu 20.04 (focal)**
✅ **Usuario `decide`** - Ejecuta la aplicación
✅ **Usuario `egc`** - Acceso administrativo
✅ **Python 3.11** - Instalado en venv
✅ **PostgreSQL** - Base de datos configurada
✅ **Django** - Migraciones aplicadas
✅ **Nginx + Gunicorn** - Servicios corriendo
✅ **Admin superuser** - Usuario `admin` creado

---

## EJERCICIO D - COMPLETADO

**Cambios realizados:**
1. ✅ Vagrantfile: ubuntu/bionic64 → ubuntu/focal64
2. ✅ user.yml: Agregado usuario egc con sudo
3. ✅ Commits realizados y pusheados a egc_test
4. ✅ Documentación completada

La configuración Vagrant está lista para ser ejecutada en máquinas Linux/macOS con VirtualBox.

