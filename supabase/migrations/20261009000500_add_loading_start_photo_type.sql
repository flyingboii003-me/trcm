-- Distinguish photos captured at the start of loading from completion photos.
alter type public.photo_type add value if not exists 'loading_start';
