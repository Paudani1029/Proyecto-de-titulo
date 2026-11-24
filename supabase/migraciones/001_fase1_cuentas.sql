-- =====================================================================
-- Lumina · Fase 1: cuentas de usuario
-- Ejecutar una vez en Supabase → SQL Editor → New query → Run.
--
-- Diferencias con la Tabla 45 (USUARIO) del documento:
--   * El correo y la contraseña los guarda Supabase Auth (tabla auth.users),
--     con hash bcrypt. Por eso aquí NO hay email ni contrasena_hash: así no se
--     duplican datos y las cuentas de Google/Outlook (sin contraseña) caben.
--   * id_usuario es el mismo UUID de auth.users (relación 1 a 1).
--   * Se quitó "usuario" (nombre de usuario): se inicia sesión con el correo.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. PERFIL (datos personales del usuario)
-- ---------------------------------------------------------------------
create table public.perfil (
  id_usuario                 uuid primary key
                             references auth.users (id) on delete cascade,
  nombre_completo            varchar(150) not null,
  fecha_nacimiento           date,
  direccion                  text,
  otra_informacion_relevante jsonb,
  fecha_creacion             timestamptz not null default now(),
  fecha_actualizacion        timestamptz not null default now()
);

comment on table public.perfil is
  'Datos personales del usuario. Correo y contraseña viven en auth.users.';

-- ---------------------------------------------------------------------
-- 2. CONFIG_ACCESIBILIDAD (una fila por usuario)
-- ---------------------------------------------------------------------
create table public.config_accesibilidad (
  id_config               uuid primary key default gen_random_uuid(),
  id_usuario              uuid not null unique
                          references auth.users (id) on delete cascade,
  tipo_discapacidad       varchar(100),
  prioridad_alertas       varchar(30) not null default 'normal'
                          check (prioridad_alertas in ('baja', 'normal', 'alta')),
  tiempo_respuesta_minimo_s real
                          check (tiempo_respuesta_minimo_s > 0),
  velocidad_tts           real not null default 0.5
                          check (velocidad_tts between 0.1 and 1.0),
  -- "Vibrar al buscar" en Ajustes
  modo_haptico_activo     boolean not null default true,
  -- Ajustes que ya existen en la app (no estaban en el documento)
  pitido_activo           boolean not null default true,
  modo_oscuro             boolean not null default false,
  fecha_actualizacion     timestamptz not null default now()
);

comment on column public.config_accesibilidad.tipo_discapacidad is
  'Dato sensible (salud) según Ley 19.628 / 21.719. Opcional.';

-- ---------------------------------------------------------------------
-- 3. fecha_actualizacion automática
-- ---------------------------------------------------------------------
create function public.marcar_actualizacion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.fecha_actualizacion := now();
  return new;
end;
$$;

create trigger perfil_actualizado
  before update on public.perfil
  for each row execute function public.marcar_actualizacion();

create trigger config_actualizada
  before update on public.config_accesibilidad
  for each row execute function public.marcar_actualizacion();

-- ---------------------------------------------------------------------
-- 4. Al crearse una cuenta, se crea su perfil y su configuración.
--    El nombre viene del formulario de registro (nombre_completo) o, si
--    entró con Google/Outlook, del nombre que entrega ese proveedor.
-- ---------------------------------------------------------------------
create function public.crear_perfil_nuevo_usuario()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.perfil (id_usuario, nombre_completo)
  values (
    new.id,
    left(
      coalesce(
        nullif(trim(new.raw_user_meta_data ->> 'nombre_completo'), ''),
        nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
        nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
        split_part(new.email, '@', 1)
      ),
      150
    )
  );

  insert into public.config_accesibilidad (id_usuario) values (new.id);
  return new;
end;
$$;

create trigger al_crear_usuario
  after insert on auth.users
  for each row execute function public.crear_perfil_nuevo_usuario();

-- ---------------------------------------------------------------------
-- 5. Seguridad por fila (RLS): cada usuario solo ve y edita lo suyo.
--    No hay políticas de INSERT/DELETE: las filas las crea el trigger y
--    se borran solas al eliminar la cuenta (on delete cascade).
-- ---------------------------------------------------------------------
alter table public.perfil enable row level security;
alter table public.config_accesibilidad enable row level security;

create policy "Ver mi perfil" on public.perfil
  for select to authenticated
  using ((select auth.uid()) = id_usuario);

create policy "Editar mi perfil" on public.perfil
  for update to authenticated
  using ((select auth.uid()) = id_usuario)
  with check ((select auth.uid()) = id_usuario);

create policy "Ver mi configuración" on public.config_accesibilidad
  for select to authenticated
  using ((select auth.uid()) = id_usuario);

create policy "Editar mi configuración" on public.config_accesibilidad
  for update to authenticated
  using ((select auth.uid()) = id_usuario)
  with check ((select auth.uid()) = id_usuario);

grant select, update on public.perfil to authenticated;
grant select, update on public.config_accesibilidad to authenticated;
