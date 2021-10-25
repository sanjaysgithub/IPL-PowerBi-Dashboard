/*----------------------------------updating year in ipl_ball ----------------------------------*/

declare @iplballcolnames nvarchar(max)

set @iplballcolnames = (
select STRING_AGG(+'ipl_ball.'+ '[' + COLUMN_NAME + ']', ',') FROM (
select COLUMN_NAME from INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'ipl_ball') t)

declare @sqlquery nvarchar(max)

set @sqlquery = 
'drop table if exists ipl_ball_updt select year(ipl_matches.date) as year, ' + @iplballcolnames + ' into ipl_ball_updt from ipl_ball
left join
 ipl_matches on ipl_ball.id = ipl_matches.id  group by ipl_matches.date, '+ @iplballcolnames +'

update ipl_ball_updt
set batting_team = ''Rising Pune Supergiants'' where batting_team = ''Rising Pune Supergiant''

update ipl_ball_updt
set bowling_team = ''Rising Pune Supergiants'' where bowling_team = ''Rising Pune Supergiant''
'
exec ( @sqlquery)

/*----------------------------------total 4s, 6s and wkts per team ----------------------------------*/

drop table if exists dbo.['boundary_flag']
select [year], [id],[batsman_runs],[batting_team],[non_boundary],[bowling_team],[is_wicket] into [dbo].['boundary_flag'] from ipl_ball_updt

alter table [dbo].['boundary_flag']
add [flag_of_6] int, [flag_of_4] int

update [dbo].['boundary_flag']
set [flag_of_6] = 1 where [batsman_runs] = '6' and [non_boundary] = '0'
update [dbo].['boundary_flag']
set [flag_of_4] = 1 where [batsman_runs] = '4' and [non_boundary] = '0'

drop table if exists dbo.['total_4sn6s']
select [year],[batting_team],sum([flag_of_6]) as [total_6s], sum([flag_of_4]) as [total_4s] into dbo.['total_4sn6s'] from [dbo].['boundary_flag'] group by [year], [batting_team]

drop table if exists dbo.['total_wkts']
select [year],[bowling_team],sum([is_wicket]) as [total_wkts] into dbo.['total_wkts'] from [dbo].['boundary_flag'] group by [year], [bowling_team]

/*----------------------------------average runs and wickets per team----------------------------------*/

drop table if exists dbo.['average_table']
select [year],[id], [batting_team], [batsman_runs],[bowling_team], [is_wicket] into  dbo.['average_table'] from ipl_ball_updt

drop table if exists dbo.['total_runs_per_team']
select [year],[batting_team] , sum([batsman_runs]) as [total_runs]  ,  COUNT(distinct[id]) as [total_matches] into dbo.['total_runs_per_team'] from dbo.['average_table'] group by [year],[batting_team]

drop table if exists dbo.['avg_runs_per_team']
select [year],[batting_team], [total_runs], [total_matches], [total_runs]/[total_matches]  as [avg_runs] into dbo.['avg_runs_per_team'] from dbo.['total_runs_per_team']

drop table if exists dbo.['total_wkts_per_team']
select [year],[bowling_team], sum([is_wicket]) as [total_wkts]  ,  COUNT(distinct[id]) as [total_matches] into dbo.['total_wkts_per_team'] from dbo.['average_table'] group by [year],[bowling_team]

drop table if exists dbo.['avg_wkts_per_team']
select [year],[bowling_team], [total_wkts], [total_matches], [total_wkts]/[total_matches]  as [avg_wkts] into dbo.['avg_wkts_per_team'] from dbo.['total_wkts_per_team']

/*----------------------------------toss winning----------------------------------*/

drop table if exists dbo.['toss_raw']
select year(date) as [year],[id], [toss_winner],[toss_decision],[winner] into dbo.['toss_raw'] from ipl_matches

update dbo.['toss_raw'] 
set [winner] = 'Rising Pune Supergiants' where [winner] = 'Rising Pune Supergiant' 

alter table dbo.['toss_raw']
add ['toss_winner_match_winner'] int

alter table dbo.['toss_raw']
add ['field_first_match_winner'] int

alter table dbo.['toss_raw']
add ['bat_first_match_winner'] int

update dbo.['toss_raw']
set ['toss_winner_match_winner'] = '1' where [toss_winner] = [winner]

update dbo.['toss_raw']
set ['toss_winner_match_winner'] = '0' where [toss_winner] != [winner]

update dbo.['toss_raw']
set ['bat_first_match_winner'] = '1' where ([toss_winner] = [winner] and [toss_decision] = 'bat') or ([toss_winner] != [winner] and [toss_decision] = 'field') 

update dbo.['toss_raw']
set ['bat_first_match_winner'] = '0' where ([toss_winner] != [winner] and [toss_decision] = 'bat') or ([toss_winner] = [winner] and [toss_decision] = 'field') 

update dbo.['toss_raw']
set ['field_first_match_winner'] = '0' where ([toss_winner] = [winner] and [toss_decision] = 'bat') or ([toss_winner] != [winner] and [toss_decision] = 'field') 

update dbo.['toss_raw']
set ['field_first_match_winner'] = '1' where ([toss_winner] != [winner] and [toss_decision] = 'bat') or ([toss_winner] = [winner] and [toss_decision] = 'field') 

/*----------------------------------most match winner----------------------------------*/

drop table if exists dbo.['match_wins']
select [year],[winner], count([winner]) as [matches_won] into dbo.['match_wins'] from ['toss_raw'] group by [year],[winner]

/*----------------------------------overall teamwise----------------------------------*/

drop table if exists dbo.['team_performance_with_NA']
select ['match_wins'].[year], ['match_wins'].winner, ['match_wins'].matches_won ,  ['total_4sn6s'].total_4s , ['total_4sn6s'].total_6s, ['avg_wkts_per_team'].avg_wkts, ['avg_wkts_per_team'].total_wkts, ['avg_runs_per_team'].total_runs, ['avg_runs_per_team'].total_matches, ['avg_runs_per_team'].avg_runs
into dbo.['team_performance_with_NA'] from (((['match_wins']
left join  ['total_4sn6s'] on ['match_wins'].winner = ['total_4sn6s'].batting_team and ['match_wins'].[year] = ['total_4sn6s'].[year] )
left join ['avg_wkts_per_team'] on ['match_wins'].winner = ['avg_wkts_per_team'].bowling_team and ['match_wins'].[year] = ['avg_wkts_per_team'].[year] )
left join ['avg_runs_per_team'] on ['match_wins'].winner = ['avg_runs_per_team'].batting_team and ['match_wins'].[year] = ['avg_runs_per_team'].[year] )

drop table if exists team_performance 
select * into team_performance from ['team_performance_with_NA'] where winner <> 'NA'


/*---------------- Player Wise Analysis -------------------- */

drop table if exists total_sixes_per_player
select batting_team, [year],batsman, count ( batsman_runs ) as total_sixes into total_sixes_per_player from ipl_ball_updt where non_boundary = 0 and batsman_runs =  6 group by batting_team, [year],batsman order by total_sixes desc

drop table if exists total_fours_per_player
select batting_team,[year],batsman, count ( batsman_runs ) as total_fours into total_fours_per_player from ipl_ball_updt where non_boundary = 0 and batsman_runs =  4 group by batting_team,[year],batsman order by total_fours desc

drop table if exists total_runs_per_player
select  batting_team,[year],batsman, sum (batsman_runs) as total_runs into total_runs_per_player from ipl_ball_updt group by batting_team,[year],batsman order by total_runs desc

drop table if exists total_wkts_per_player
select [bowling_team],[year],bowler, COUNT( is_wicket ) as total_wkts into total_wkts_per_player from ipl_ball_updt where is_wicket = 1 group by [bowling_team],[year],bowler order by total_wkts desc

--drop table if exists total_mom_per_player
--select year([date]) as [year], player_of_match as player, count(player_of_match) as no_of_man_of_match into total_mom_per_player from ipl_matches group by ipl_matches.date, player_of_match order by no_of_man_of_match desc

--select * from total_mom_per_player order by no_of_man_of_match asc

drop table if exists player_list_duplicate
select [year], bowler as player into player_list_duplicate from ipl_ball_updt
union all 
select [year],batsman from ipl_ball_updt

drop table if exists player_list
select distinct * into player_list from player_list_duplicate
drop table player_list_duplicate

drop table if exists player_performance_duplicate
select total_sixes_per_player.batting_team, total_wkts_per_player.bowling_team, [player_list].[year],player_list.player, total_runs_per_player.total_runs,  total_sixes_per_player.total_sixes, total_fours_per_player.total_fours,  total_wkts_per_player.total_wkts
into player_performance_duplicate from ((((player_list
left join total_runs_per_player on player_list.player = total_runs_per_player.batsman and [player_list].[year] = total_runs_per_player.[year])
left join total_sixes_per_player on player_list.player = total_sixes_per_player.batsman and [player_list].[year]  = total_sixes_per_player.[year])
left join total_fours_per_player on player_list.player = total_fours_per_player.batsman and [player_list].[year] = total_fours_per_player.[year])
left join total_wkts_per_player on player_list.player = total_wkts_per_player.bowler and [player_list].[year] = total_wkts_per_player.[year])
--left join total_mom_per_player on player_list.player = total_mom_per_player.player and [player_list].[year] = total_mom_per_player.[year])

drop table if exists player_performance 
select distinct * into player_performance from player_performance_duplicate 

update player_performance
set total_runs = 0 where total_runs is null

update player_performance
set total_sixes = 0 where total_sixes is null

update player_performance
set total_fours = 0 where total_fours is null

update player_performance
set total_wkts = 0 where total_wkts is null

update player_performance
set bowling_team = 0 where bowling_team is null

update player_performance
set batting_team = 0 where batting_team is null

alter table player_performance
add team nvarchar (max)

update player_performance
set team = batting_team + bowling_team where batting_team = '0' or bowling_team = '0'

update player_performance
set team = batting_team where batting_team! = '0' and bowling_team! = '0'

update player_performance
set team = TRIM('0' from team) 

delete player_performance where team = ''
delete player_performance where team = 'NA'

alter table player_performance
drop column batting_team

alter table player_performance
drop column bowling_team

/*---------------- Final Table -------------------- */
select * from team_performance 
select * from player_performance










