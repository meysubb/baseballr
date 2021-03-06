#' Scrape and clean NCAA baseball play by play (Division I, II, and III)
#'
#' This function allows the user to obtain cleaned PBP data for individal teams, a conference, or all teams for that season
#'
#' @param season True or False, NCAA PBP by Season or Individual Teams.
#' @param division Select what division of college baseball 
#' @param teamid The numerical ID that the NCAA website uses to identify a team
#' @param conf Select a conference, naming convention can be found in master_ncaa_team_lu
#' @keywords baseball, NCAA, college
#' @import dplyr
#' @import assertthat
#' @import XML
#' @import RCurl
#' @import furrr
#' @import future
#' @importFrom tidyr "unnest"
#' @export ncaa_get_pbp
#' @examples
#' \dontrun{
#' ncaa_get_pbp(season=F,year=2017,division=1,teamid=697)
#' ncaa_get_pbp(season=T,year=2017,division=1,conference="SEC")
#' }
#' 
#' 
ncaa_get_pbp <- function(season=F,year,division=1,teamid=NULL,conference=NULL){
  if(season){
    ### extract get_season_pbp
    raw_season_pbp <- .get_season_pbp(year=year,division=division,conference=conference)
    print("The raw data has been pulled, it is being cleaned. Patience will be rewarded.")
    clean_pbp <- .ncaa_parse_pbp(raw_season_pbp)
  } else {
    ### extract get_team_pbo 
    if(is.null(teamid)){
      stop('A Team ID was not selected, please select one. Reference master_ncaa_lu if need be')
    }else{
      raw_team_pbp <- .get_team_pbp(teamid,year=year,division=division) 
      print("The raw data has been pulled, it is being cleaned. Patience will be rewarded.")
      clean_pbp <- .ncaa_parse_pbp(raw_team_pbp)
    }
    
  }
  return(clean_pbp)
}



### Helper Functions from here on out. 
stripwhite <- function(x) gsub("\\s*$", "", gsub("^\\s*", "", x))

.score_fill=function(score_in){
  m=length(score_in)
  score_in[1]=0
  for(i in 2:m){
    if (is.na(score_in[i])){
      score_in[i]=score_in[i-1]
    }
  }
  return(score_in)
}

.clean_games = function(game_id,year){
  print(paste0('Processing pbp for ',game_id))
  first_url='https://stats.ncaa.org/contests/'
  first_x = paste(first_url,game_id,'box_score',sep='/')
  adv_game_id = read_html(first_x) %>% html_nodes("#root li:nth-child(3) a") %>% html_attr("href")
  
  base_url='http://stats.ncaa.org'
  x= paste(base_url, adv_game_id, sep='/')
  #Sys.sleep(1)
  x_read <- try(getURL(x))
  if (class(x_read)=='try-error'){
    print(paste('Cannot connect to server for', game_id, 'in', year))
    return(NULL)
  }
  y=readHTMLTable(x_read)
  # Play by play is in table form
  y = y[which(!sapply(y,is.null))]
  
  if (length(y) == 0 |  (length(y) < ncol(y[[3]])) ) {
    print(paste("Play by Play data not available for game", game_id, sep=' '))
    next
  }
  else{
    j=1
    for (i in 1:length(y)){
      # Disgard NULL tables
      if (is.null(y[[i]])==FALSE){
        # Only take pbp tables (3 cols)
        if (ncol(y[[i]])==3){
          inn=as.data.frame(y[[i]])%>%
            mutate(inning=j,
                   game_id=game_id,
                   year=year)%>%
            select(year,game_id,inning,everything())
          j=j+1
          if(j==2){
            pbp = inn
          }else{
            pbp = rbind(pbp,inn)
          }
        }
      }
    }
  }
  if(!exists('pbp')){
    return(NULL)
  }
  pbp = pbp %>% mutate(away_team = colnames(pbp)[4],
                       home_team = colnames(pbp)[6],
                       away_score = as.integer(gsub('-.*', '', Score)),
                       home_score = as.integer(gsub('.*-', '', Score)),
                       away_score=.score_fill(away_score),
                       home_score=.score_fill(home_score))%>%
    rename(away_text = 4,
           home_text = 6)%>%
    filter(substr(away_text,1,3)!='R: ')%>%
    select(year, game_id, inning, away_team, home_team, away_score, home_score, away_text, home_text)
  return(pbp)
}

# Get pbp from all games for one team
.get_team_pbp=function(teamid, year, division=1){
  all_team_games=ncaa_get_team_schedule(teamid, year, division=1)
  
  
  games=all_team_games%>%
    distinct(GameId, .keep_all = TRUE)%>%
    mutate(home_team=ifelse(Loc%in%c('H', 'N'), Team, Opp),
           away_team=ifelse(Loc=='H', Opp, Team ))%>%
    select(Year, Date, GameId, home_team, away_team)
  
  
  print('Processing Play-by-Play')    
  
  game_pbp = games %>% mutate(
    pbp_raw = furrr::future_map2(GameId,Year,.clean_games,.progress = TRUE)
  )  
  
  inds <- sapply(game_pbp$pbp_raw,is.null)
  game_pbp <- game_pbp[!inds,]
  
  pbp_final <- game_pbp %>% select(pbp_raw) %>% unnest()  
  return(pbp_final)
}

# Get pbp from all games in one season
.get_season_pbp=function(year, division=1,conference=NULL){
  
  if(!is.null(conference)){
    all_season_games <- ncaa_get_season_schedule(year, div=division,conf=conference)
  }
  if(is.null(conference)){
    all_season_games <- ncaa_get_season_schedule(year, div=division)
  }
  
  
  print('Processing Play-by-Play')    
  
  
  games=all_season_games %>%
    distinct(GameId, .keep_all = TRUE) %>%
    mutate(home_team=ifelse(Loc %in% c('H', 'N'), Team, Opp),
           away_team=ifelse(Loc=='H', Opp, Team )) %>% 
    select(Year, Date, GameId, home_team, away_team)
  
  season_pbp = games %>% mutate(
    pbp_raw = furrr::future_map2(GameId,Year,.clean_games,.progress = TRUE))
  
  inds <- sapply(season_pbp$pbp_raw,is.null)
  season_pbp <- season_pbp[!inds,]
  
  pbp_final <- season_pbp %>% select(pbp_raw) %>% unnest()  
  return(pbp_final)
}