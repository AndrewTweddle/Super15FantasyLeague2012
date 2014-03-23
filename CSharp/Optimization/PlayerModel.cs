using System;

namespace FantasyLeague
{
    public enum AllowedRole
    {
        Excluded = 0,
        Captain = 1,
        Kicker = 2,
        Other = 3
    }
    
    public enum AllowedRounds
    {
        None = 0,
        RoundRobin = 1,
        PlayOffs = 2,
        All = 3
    }
    
    public class PlayerModel: IComparable<PlayerModel>, IEquatable<PlayerModel>
    {
        public string PlayerId
        {
            get
            {
                return System.Text.RegularExpressions.Regex.Replace(FullName, @"\W", String.Empty);
            }
        }
        
        public bool ScoreAllRemainingRounds
        {
            get;
            set;
        }
        
        public int Round { get; set; }
        
        public AllowedRole AllowedRole
        {
            get;
            set;
        }
        
        public AllowedRounds AllowedRounds
        {
            get;
            set;
        }
        
        public bool IncludeInModel 
        {
            get
            {
                return AllowedRole != AllowedRole.Excluded;
            }
            set
            {
                if (value)
                {
                    AllowedRole = FantasyLeague.AllowedRole.Other;
                }
                else
                {
                    AllowedRole = FantasyLeague.AllowedRole.Excluded;
                }
            }
        }
        public bool IsInjured { get; set; }
        public double IsInTeam { get; set; }
        public double IsCaptain { get; set; }
        public double IsKicker { get; set; }
        public double IsSubstitute { get; set; }
        public double IsNormalPlayer 
        {
            get
            {
                return IsInTeam == 1 && IsCaptain == 0 && IsKicker == 0 && IsSubstitute == 0 ? 1 : 0;
            }
        }
        
        public string Role 
        { 
            get 
            {
                return ( IsCaptain != 0 ? "C" : String.Empty)
                     + ( IsKicker != 0 ? "K" : String.Empty)
                     + ( IsNormalPlayer != 0 ? "P" : String.Empty)
                     + ( IsSubstitute != 0 ? "S" : String.Empty);
            }
        }
        
        public string RoundAsString
        {
            get
            {
                return String.Format("Rnd{0}", Round);
            }
        }
        
        public string PreviousRole { get; set; }
        
        public string FullName { get; set; }
        public int Priority { get; set; }
        public bool K { get; set; }
        public bool C { get; set; }
        public bool P { get; set; }
        public string Position { get; set; }
        public string Team { get; set; }
        public int GamesPlayed { get; set; }
        public double Price { get; set; }
        public double NonKickerTotal { get; set; }
        public double KickerTotal { get; set; }
        
        public double NonKickerScoreForRound
        {
            get
            {
                double score = 0.0;
                
                if (Round == 0)
                {
                    score = (NonKickerScoresForRound[0] + NonKickerScoresForRound[1] +  NonKickerScoresForRound[2])/3;
                }
                
                if (ScoreAllRemainingRounds)
                {
                    double sum = 0;
                    for (int i = Round - 1; i < 18; i++)
                    {
                        sum += NonKickerScoresForRound[i];
                    }
                    score = sum;
                }
                
                // Debugging...
                if (Round > NonKickerScoresForRound.Length)
                {
                    Console.WriteLine("Index out of range - round {0}, {1} records, player: {2}", 
                        Round, NonKickerScoresForRound.Length, FullName);
                }
                
                score = NonKickerScoresForRound[Round-1];
                
                if (IsInjured)
                {
                    score = 0.1 * score;  
                        // This is so that an injured player is still preferred over one whose team is definitely not playing
                }
                return score;
            }
        }
        
        public double KickerScoreForRound
        {
            get
            {
                double score = 0.0;
                
                if (Round == 0)
                {
                    score = (KickerScoresForRound[0] + KickerScoresForRound[1] +  KickerScoresForRound[2])/3;
                }
                if (ScoreAllRemainingRounds)
                {
                    double sum = 0;
                    for (int i = Round - 1; i < 18; i++)
                    {
                        sum += KickerScoresForRound[i];
                    }
                    score = sum;
                }
                score = KickerScoresForRound[Round-1];
                
                if (IsInjured)
                {
                    score = 0.1 * score;  
                        // This is so that an injured player is still preferred over one whose team is definitely not playing
                }
                return score;
            }
        }

        public double CaptainScoreForRound
        {
            get
            {
                return 2 * NonKickerScoreForRound;
            }
        }
        
        public double[] NonKickerScoresForRound { get; set; }
        public double[] KickerScoresForRound { get; set; }
        public int One { get { return 1; } }
        public bool True { get { return true; } }
        
        public PlayerModel Clone(int round)
        {
            PlayerModel pm = new PlayerModel
            {
                ScoreAllRemainingRounds = this.ScoreAllRemainingRounds,
                Round = round,
                AllowedRole = this.AllowedRole,
                AllowedRounds = this.AllowedRounds,
                IsInTeam= this.IsInTeam,
                IsCaptain= this.IsCaptain,
                IsKicker= this.IsKicker,
                IsSubstitute= this.IsSubstitute,
                FullName= this.FullName,
                Priority= this.Priority,
                IsInjured = this.IsInjured,
                K= this.K,
                C= this.C,
                P= this.P,
                Position= this.Position,
                Team= this.Team,
                GamesPlayed= this.GamesPlayed,
                Price= this.Price,
                PreviousRole = this.PreviousRole,
                NonKickerTotal= this.NonKickerTotal,
                KickerTotal= this.KickerTotal,
                NonKickerScoresForRound = new double[21],
                KickerScoresForRound = new double[21]
            };
            Array.Copy(this.NonKickerScoresForRound, pm.NonKickerScoresForRound, 21);
            Array.Copy(this.KickerScoresForRound, pm.KickerScoresForRound, 21);
            return pm;
        }

        public int CompareTo(PlayerModel other)
        {
            int comp = this.FullName.CompareTo(other.FullName);
            if (comp == 0)
            {
                return this.Round.CompareTo(other.Round);
            }
            else
            {
                return comp;
            }
        }

        public bool Equals(PlayerModel other)
        {
            return CompareTo(other) == 0;
        }

        public override bool Equals(object obj)
        {
            if (obj is PlayerModel)
            {
                return this.Equals((PlayerModel)obj);
            }
            return false;
        }

        public override int GetHashCode()
        {
            return FullName.GetHashCode() * 1001 ^ Round.GetHashCode();
        }
    }
}