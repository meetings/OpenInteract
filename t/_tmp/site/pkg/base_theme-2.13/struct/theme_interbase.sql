CREATE TABLE theme (
 theme_id      %%INCREMENT%%,
 title         varchar(50) not null,
 description   blob,
 parent        %%INCREMENT_TYPE%% not null,
 credit        varchar(200),
 primary key   ( theme_id )
)
