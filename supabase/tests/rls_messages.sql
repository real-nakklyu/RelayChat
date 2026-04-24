begin;
select plan(5);

select has_table('public', 'messages', 'messages table exists');
select has_policy('public', 'messages', 'participants read messages');
select has_policy('public', 'messages', 'participants send messages');
select has_policy('public', 'blocked_users', 'users block others');
select has_policy('storage', 'objects', 'participants read stored attachments');

select * from finish();
rollback;
