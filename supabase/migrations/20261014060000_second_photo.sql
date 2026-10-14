-- Second (optional) photo per item
alter table public.vestiti add column if not exists photo_path2 text;
