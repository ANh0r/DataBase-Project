--�����û���
create table users(
account varchar(30) primary key,
passwd varchar(30) not null,
id varchar(10) check (id in ('����Ա','����'))
)
--�������߱�
create table readers(
borrowid varchar(30) primary key,
rname varchar(30) not null,
sex varchar(2) check (sex in ('��','Ů')),
job varchar(10),
rCurNum int,
rBorrowedNum int,
dept varchar(20),
phone varchar(20),
account varchar(30) foreign key references users(account) 
	on delete cascade
	on update cascade
)
--����ͼ���
create table books(
isbn varchar(30) primary key,
bname varchar(30) not null,
pub varchar(30) not null,
author varchar(15) not null,
storeNum int,
bCurNum int,
available char(2) check (available in ('��','��'))
)
--����account��uniqueԼ��
alter table readers add constraint UQ_1 unique(account);

--�������Ĺ�ϵ��
create table rb(
borrowid varchar(30) references readers(borrowid)
	on delete cascade
	on update cascade,
isbn varchar(30) references books(isbn)
	on delete cascade
	on update cascade,
startDate date,
duration int,
returnDate date,
fine int,
primary key(borrowid,isbn)
)
--������Ա��ɫ����Ȩ�ޣ�
grant all privileges
on readers
to admin

grant all privileges
on books
to admin

grant select
on rb
to admin
--�����߽�ɫ����Ȩ�ޣ�
grant insert,delete,select
on rb
to reader

grant select
on readers
to reader

grant select	//��¼ʱ�ܹ��ж����
on users
to reader

grant select on books
to reader

grant update
on books(bCurNum)
to reader
--���봥������ֹ���߱�Ĳ���������account�����û����еĶ��ߣ�
create trigger insertReaderOnly
on readers
for insert
as
begin
	if exists(select inserted.account from inserted,users where inserted.account=users.account and users.id!='����')
	begin
		delete from readers where account in (select account from inserted)
		and account in (select account from users where id!='����')
		
		RAISERROR ('�ö���δ�Զ������ע��!',15,1)
	end
end

create trigger updateReaderOnly
on readers
for update
as
begin
	if exists(select inserted.account from inserted,users where inserted.account=users.account and users.id!='����')
	begin
		rollback
		
		RAISERROR ('�ö���δ�Զ������ע��!',15,1)
	end
end
--����Ĵ�������
create trigger borrowTrigger
on rb
for insert
as
begin
	declare @borrowid varchar(30)
	declare @isbn varchar(30)
	select @borrowid=borrowid,@isbn=isbn from inserted
	
	if((select available from books where isbn=@isbn)='��' or (select rCurNum from readers where borrowid=@borrowid)<=0)
	begin
		delete from rb where borrowid=@borrowid and isbn=@isbn
		RAISERROR ('���鲻�ɽ�!',15,1)
	end
	else if(not exists(select * from rb where CONVERT(varchar(10),GETDATE(),120)>returnDate and borrowid=@borrowid and isbn!=@isbn))
	begin
		update books set bCurNum=bCurNum-1 
		where isbn=@isbn
		update readers set rCurNum=rCurNum-1
		where borrowid=@borrowid
		update readers set rBorrowedNum=rBorrowedNum+1
		where borrowid=@borrowid
		
		if((select bCurNum from books where isbn=@isbn)=0)
		begin
			update books set available='��' where isbn=@isbn
		end
	end
	else
	begin
		delete from rb where borrowid=@borrowid and isbn=@isbn
		RAISERROR ('�ö��ߵ�ǰ����δ���鼮�����ܽ���!',15,1)
	end
end
--���鴥������
create trigger returnTrigger
on rb
for delete
as
begin
	declare @isbn varchar(30)
	declare @borrowid varchar(30)
	select distinct @isbn=isbn from deleted
	select distinct @borrowid=borrowid from deleted
	
	update books set bCurNum=bCurNum+1 where isbn=@isbn
	update books set available='��' where isbn=@isbn
	update readers set rCurNum=rCurNum+1 where borrowid=@borrowid
	update readers set rBorrowedNum=rBorrowedNum-1 where borrowid=@borrowid
end
--���һ���洢���̣���ͼ����Ϊ������������ؽ��ĸ�ͼ�鵫δ�黹�Ķ��������ͽ���֤�ţ��洢����û�з���ֵ������д�ɴ洢��������
create function getUnReturnReaders
(
	@isbn varchar(30)
)
returns table
as
return
(
	select readers.rname,readers.borrowid from readers,rb
	where readers.borrowid=rb.borrowid and 
	CONVERT(varchar(10),GETDATE(),120)>returnDate and
	isbn=@isbn
)
--�������ϲ�ѯ�����һ���ж����������Ĵ洢���̣����ض��ߵ���ϸ��Ϣ�������һ�洢���̲��Զ��߽���֤��Ϊ������������ظö���δ�黹��ͼ�����ƺ�ͼ���ţ��洢����û�з���ֵ������д�ɴ洢��������
--�������ϲ�ѯ�Ĵ洢������
create function getReaderInfo
(
	@borrowid varchar(30),
	@rname varchar(30),
	@sex varchar(5),
	@job varchar(30),
	@rCurNum int,
	@rBorrowedNum int,
	@dept varchar(30),
	@phone varchar(15),
	@account varchar(30)
)
returns table
as
return
(
	select * from readers where
	borrowid=@borrowid and rname=@rname
	and sex=@sex and job=@job and rCurNum>=@rCurNum
	and rBorrowedNum>=@rBorrowedNum and dept=@dept
	and phone=@phone and account=@account
)
--�鿴����δ����ͼ�����ƺ�ͼ��ţ�
create function getUnReturnBooks
(
	@borrowid varchar(30)
)
returns table
as
return
(
	select bname,books.isbn from books,rb
	where books.isbn=rb.isbn and rb.borrowid=@borrowid
	and CONVERT(varchar(10),GETDATE(),120)>returnDate
)
--����ͼ���ѯ�����һ����ͼ��������������δ�黹��ͼ��ı�š�������������������Ϣ��
create view delayedInfos
as
select rb.isbn,rname,bname from rb,books,readers
where rb.isbn=books.isbn and rb.borrowid=readers.borrowid
and CONVERT(varchar(10),GETDATE(),120)>returnDate
--�ӿ����ݼ����ٶȣ���ͼ����Ϊͼ����Ϣ����������
create clustered index IsbnIndex on books(isbn)
--���Ĵ���Ϊ������Ϣ�����INSERT���������ڶ��߽���ʱ����ISBN�����Ϣ���ҿɽ�������1��ͼ����Ϣ���Ƿ�ɽ��е�ֵ��Ϊ�����ɽ衱��������Ϣ���и�������ѽ�������1��
--�ο�����Ľ��鴥����

--���鴦��Ϊ������Ϣ�����UPDATE���������ڸñ�Ĺ黹�����б����ĺ󣬽�ͼ����Ϣ����Ƿ�ɽ��е�ֵ��Ϊ���ɽ衱��������Ϣ�����ѽ�������1��ISBN�����Ϣ���пɽ�������1��
--�ο����ϵĻ��鴥����
