# frozen_string_literal: true

##
module Ballot
  # Methods added to a model that is marked as a Votable.
  module Votable
    ##
    # If the model is caching the ballot summary (in a JSON-serialized column
    # called +cached_ballot_summary+), we want to ensure that it is initialized
    # to a Hash if it is not set.
    def initialize(*)
      super
      self.cached_ballot_summary ||= {} if caching_ballot_summary?
    end

    ##
    # Indicate whether a ballot has been registered on the current instance of
    # this model. Votes are registered if and only if the vote is a *change*
    # from the previous vote.
    #
    #     post = Post.create(title: 'my amazing post')
    #     copy = post.dup
    #     post.down_ballot_by current_user
    #     post.ballot_registered? # => true
    #     copy.up_ballot_by current_user # => true
    #     copy.up_ballot_by_current_user # => false
    #     post.ballot_registered? # => true
    def ballot_registered?
      @ballot_registered
    end

    #-----
    # :section: Recording Votes
    #-----

    ##
    # :method: ballot_by
    # :call-seq:
    #    ballot_by(voter = nil, kwargs = {})
    #    ballot_by(voter)
    #    ballot_by(voter_id: id, voter_type: type)
    #    ballot_by(voter_gid: gid)
    #    ballot_by(voter, scope: scope, vote: false, weight: true)
    #
    # Record a Vote for this Votable by the provided +voter+. The +voter+ may
    # be specified as its own parameter, or through the keyword arguments
    # +voter_id+, +voter_type+, +voter_gid+, or +voter+ (note that the
    # parameter +voter+ will override the keyword argument +voter+, if both are
    # provided).
    #
    # Additional named arguments may be provided through +kwargs+:
    #
    # scope:: The scope of the vote to be recorded. Defaults to +nil+.
    # vote:: The vote to be recorded. Defaults to +true+ and is parsed through
    #        Ballot::Words.truthy?.
    # weight:: The weight of the vote to be recorded. Defaults to +1+.
    # duplicate:: Allow a duplicate vote to be recorded. This is not
    #             recommended as it has negative performance implications at
    #             scale.
    #
    # Other arguments are ignored.
    #
    # \ActiveRecord:: There are no special notes for ActiveRecord.
    # \Sequel:: GlobalID does not currently provide support for Sequel. The use
    #           of +voter_gid+ in this case will probably fail.

    ##
    # Records a positive vote by the provided +voter+ with options provided in
    # +kwargs+. Any value passed to the +vote+ keyword argument will be
    # ignored. See #ballot_by for more details.
    def up_ballot_by(voter = nil, kwargs = {})
      ballot_by(voter, kwargs.merge(vote: true))
    end

    ##
    # Records a negative vote by the provided +voter+ with options provided in
    # +kwargs+. Any value passed to the +vote+ keyword argument will be
    # ignored. See #ballot_by for more details.
    def down_ballot_by(voter = nil, kwargs = {})
      ballot_by(voter, kwargs.merge(vote: false))
    end

    ##
    # :method: remove_ballot_by
    # :call-seq:
    #    remove_ballot_by(voter = nil, kwargs = {})
    #    remove_ballot_by(voter)
    #    remove_ballot_by(voter_id: id, voter_type: type)
    #    remove_ballot_by(voter_gid: gid)
    #    remove_ballot_by(voter, scope: scope)
    #
    # Remove any votes for this Votable by the provided +voter+. The +voter+
    # may be specified as its own parameter, or through the keyword arguments
    # +voter_id+, +voter_type+, +voter_gid+, or +voter+ (note that the
    # parameter +voter+ will override the keyword argument +voter+, if both are
    # provided).
    #
    # Only the +scope+ argument is available through +kwargs+:
    #
    # scope:: The scope of the vote to be recorded. Defaults to +nil+.
    #
    # Other arguments are ignored.
    #
    # \ActiveRecord:: There are no special notes for \ActiveRecord.
    # \Sequel:: GlobalID does not currently provide support for \Sequel, so
    #           there are many cases where attempting to use +voter_gid+ will
    #           fail.

    #-----
    # :section: Finding Votes
    #-----

    ##
    # :method: ballots_for
    #
    # The votes attached to this Votable.
    #
    # \ActiveRecord:: This is generated by the polymorphic association
    #                 <tt>has_many :ballots_for</tt>.
    # \Sequel:: This is generated by the polymorphic association
    #           <tt>one_to_many :ballots_for</tt>

    ##
    # :method: ballots_for_dataset
    #
    # The \Sequel association dataset for votes attached to this Votable.
    #
    # \ActiveRecord:: This does not exist for \ActiveRecord.
    # \Sequel:: This is generated by the polymorphic association
    #           <tt>one_to_many :ballots_for</tt>

    ##
    # Returns ballots for this Votable where the recorded vote is positive.
    #
    # \ActiveRecord:: There are no special notes for ActiveRecord.
    # \Sequel:: This method returns the _dataset_; if vote objects are desired,
    #           use <tt>up_ballots_for.all</tt>.
    def up_ballots_for(scope: nil)
      find_ballots_for(vote: true, scope: scope)
    end

    ##
    # Returns ballots for this Votable where the recorded vote is negative.
    #
    # \ActiveRecord:: There are no special notes for ActiveRecord.
    # \Sequel:: This method returns the _dataset_; if vote objects are desired,
    #           use <tt>down_ballots_for.all</tt>.
    def down_ballots_for(scope: nil)
      find_ballots_for(vote: false, scope: scope)
    end

    #-----
    # :section: Voter Inquiries
    #-----

    ##
    # :method: ballot_by?
    # :call-seq:
    #    ballot_by?(voter = nil, kwargs = {})
    #    ballot_by?(voter)
    #    ballot_by?(voter_id: id, voter_type: type)
    #    ballot_by?(voter_gid: gid)
    #    ballot_by?(voter, scope: scope, vote: false, weight: true)
    #
    # Returns +true+ if the provided +voter+ has made votes for this Votable
    # matching the provided criteria. The +voter+ may be specified as its own
    # parameter, or through the keyword arguments +voter_id+, +voter_type+,
    # +voter_gid+, or +voter+ (note that the parameter +voter+ will override
    # the keyword argument +voter+, if both are provided).
    #
    # Additional named arguments may be provided through +kwargs+:
    #
    # scope:: The scope of the vote to be recorded. Defaults to +nil+.
    # vote:: The vote to be queried. If present, is parsed through
    #        Ballot::Words.truthy?.
    #
    # Other arguments are ignored.
    #
    # \ActiveRecord:: There are no special notes for ActiveRecord.
    # \Sequel:: GlobalID does not currently provide support for Sequel. The use
    #           of +voter_gid+ in this case will probably fail.

    ##
    # Returns +true+ if the provided +voter+ has made positive votes for this
    # Votable. Any value passed to the +vote+ keyword argument will be ignored.
    # See #ballot_by? for more details.
    def up_ballot_by?(voter = nil, kwargs = {})
      ballot_by?(voter, kwargs.merge(vote: true))
    end

    ##
    # Returns +true+ if the provided +voter+ has made negative votes for this
    # Votable. Any value passed to the +vote+ keyword argument will be ignored.
    # See #ballot_by? for more details.
    def down_ballot_by?(voter = nil, kwargs = {})
      ballot_by?(voter, kwargs.merge(vote: false))
    end

    ##
    # :method: ballots_by_class(model_class, kwargs = {})
    #
    # Find ballots cast for this Votable matching the canonical name of the
    # +model_class+ as the type of Voter.
    #
    # Additional named arguments may be provided through +kwargs+:
    #
    # scope:: The scope of the vote to be recorded. Defaults to +nil+.
    # vote:: The vote to be queried. If present, is parsed through
    #        Ballot::Words.truthy?.
    #
    # Other arguments are ignored.

    ##
    # Find positive ballots cast by this Voter matching the canonical name of
    # the +model_class+ as the type of Voter. Any value passed to the +vote+
    # keyword argument will be ignored. See #ballots_by_class for more details.
    def up_ballots_by_class(model_class, kwargs = {})
      ballots_by_class(model_class, kwargs.merge(vote: true))
    end

    ##
    # Find negative ballots cast by this Voter matching the canonical name of
    # the +model_class+ as the type of Voter. Any value passed to the +vote+
    # keyword argument will be ignored. See #ballots_by_class for more details.
    def down_ballots_by_class(model_class, kwargs = {})
      ballots_by_class(model_class, kwargs.merge(vote: false))
    end

    ##
    # Returns the Voter objects that have made votes on this Votable.
    # Additional query conditions may be specified in +conds+, or in the
    # +block+ if supported by the ORM. The Voter objects are eager loaded to
    # minimize the number of queries required to satisfy this request.
    #
    # \ActiveRecord:: Polymorphic eager loading is directly supported, using
    #                 <tt>ballots_for.includes(:voter)</tt>. Normal
    #                 +where+-clause conditions may be provided in +conds+.
    # \Sequel:: Polymorphic eager loading is not supported by \Sequel, but has
    #           been implemented in Ballot for this method. Normal
    #           +where+-clause conditions may be provided in +conds+ or in
    #           +block+ for \Sequel virtual row support.
    def ballot_voters(*conds, &block)
      __eager_ballot_voters(find_ballots_for(*conds, &block))
    end

    ##
    # Returns the Voter objects that have made positive votes on this Votable.
    # See #ballot_voters for how +conds+ and +block+ apply.
    def up_ballot_voters(*conds, &block)
      __eager_ballot_voters(
        find_ballots_for(*conds, &block).where(vote: true)
      )
    end

    ##
    # Returns the Voter objects that have made negative votes on this Votable.
    # See #ballot_voters for how +conds+ and +block+ apply.
    def down_ballot_voters(*conds, &block)
      __eager_ballot_voters(
        find_ballots_for(*conds, &block).where(vote: false)
      )
    end

    #-----
    # :section: Ballot Summaries and Caching
    #-----

    ##
    # :attr_accessor: cached_ballot_summary
    #
    # A Hash object used for caching balloting summaries for this Votable. When
    # caching is enabled, all scopes and values are cached. For each scope,
    # this caches:
    #
    # * The total number of ballots cast (#total_ballots);
    # * The total number of positive (up) ballots cast (#total_up_ballots);
    # * The total number of negative (down) ballots cast (#total_down_ballots);
    # * The ballot score (number of up ballots less the number of down ballots,
    #   #ballot_score);
    # * The weighted ballot total (sum of ballot weights,
    #   #weighted_ballot_total);
    # * The weighted ballot score (the sum of up ballot weights less the sum of
    #   down ballot weights; #weighted_ballot_score);
    # * The weighted ballot average (the weighted ballot score over the number
    #   of votes, #weighted_ballot_average).
    #
    # <em>Present only if the column +cached_ballot_summary+ exists on
    # the underlying Votable.</em>

    ##
    # The total number of ballots cast for this Votable in the provided
    # +scope+. If +scope+ is not provided, reports for the _default_ scope.
    #
    # If the Votable has a +cached_ballot_summary+ column and +skip_cache+ is
    # +false+, returns the cached total.
    def total_ballots(scope = nil, skip_cache: false)
      if !skip_cache && caching_ballot_summary?
        scoped_cache_summary(scope)['total'].to_i
      else
        find_ballots_for(scope: scope).count
      end
    end

    ##
    # The total number of positive ballots cast for this Votable in the
    # provided +scope+. If +scope+ is not provided, reports for the _default_
    # scope.
    #
    # If the Votable has a +cached_ballot_summary+ column and +skip_cache+ is
    # +false+, returns the cached total.
    def total_up_ballots(scope = nil, skip_cache: false)
      if !skip_cache && caching_ballot_summary?
        scoped_cache_summary(scope)['up'].to_i
      else
        up_ballots_for(scope: scope).count
      end
    end

    ##
    # The total number of negative ballots cast for this Votable in the
    # provided +scope+. If +scope+ is not provided, reports for the _default_
    # scope.
    #
    # If the Votable has a +cached_ballot_summary+ column and +skip_cache+ is
    # +false+, returns the cached total.
    def total_down_ballots(scope = nil, skip_cache: false)
      if !skip_cache && caching_ballot_summary?
        scoped_cache_summary(scope)['down'].to_i
      else
        down_ballots_for(scope: scope).count
      end
    end

    ##
    # The computed score of ballots cast (total positive ballots less total
    # negative ballots) for this Votable in the provided +scope+. If +scope+ is
    # not provided, reports for the _default_ scope.
    #
    # If the Votable has a +cached_ballot_summary+ column and +skip_cache+ is
    # +false+, returns the cached score.
    def ballot_score(scope = nil, skip_cache: false)
      if !skip_cache && caching_ballot_summary?
        scoped_cache_summary(scope)['score'].to_i
      else
        total_up_ballots(scope, skip_cache: skip_cache) -
          total_down_ballots(scope, skip_cache: skip_cache)
      end
    end

    ##
    # The weighted total of ballots cast (the sum of all ballot +weights+) for
    # this Votable in the provided +scope+. If +scope+ is not provided, reports
    # for the _default_ scope.
    #
    # If the Votable has a +cached_ballot_summary+ column and +skip_cache+ is
    # +false+, returns the cached score.
    def weighted_ballot_total(scope = nil, skip_cache: false)
      if !skip_cache && caching_ballot_summary?
        scoped_cache_summary(scope)['weighted_ballot_total'].to_i
      else
        find_ballots_for(scope: scope).sum(:weight).to_i
      end
    end

    ##
    # The weighted score of ballots cast (the sum of all positive ballot
    # +weight+s less the sum of all negative ballot +weight+s) for this Votable
    # in the provided +scope+. If +scope+ is not provided, reports for the
    # _default_ scope.
    #
    # If the Votable has a +cached_ballot_summary+ column and +skip_cache+ is
    # +false+, returns the cached score.
    def weighted_ballot_score(scope = nil, skip_cache: false)
      if !skip_cache && caching_ballot_summary?
        scoped_cache_summary(scope)['weighted_ballot_score'].to_i
      else
        up_ballots_for(scope: scope).sum(:weight).to_i -
          down_ballots_for(scope: scope).sum(:weight).to_i
      end
    end

    ##
    # The weighted average of ballots cast (the weighted ballot score over the
    # total number of votes cast) for this Votable in the provided +scope+. If
    # +scope+ is not provided, reports for the _default_ scope.
    #
    # If the Votable has a +cached_ballot_summary+ column and +skip_cache+ is
    # +false+, returns the cached average.
    def weighted_ballot_average(scope = nil, skip_cache: false)
      if !skip_cache && caching_ballot_summary?
        scoped_cache_summary(scope)['weighted_ballot_average'].to_i
      elsif (count = total_ballots) > 0
        weighted_ballot_score.to_f / count
      else
        0.0
      end
    end

    private

    attr_writer :ballot_registered

    def calculate_summary(scope = nil)
      {}.tap do |summary|
        summary[scope] ||= {}
        summary[scope]['total'] = total_ballots(scope, skip_cache: true)
        summary[scope]['up'] = total_up_ballots(scope, skip_cache: true)
        summary[scope]['down'] = total_down_ballots(scope, skip_cache: true)
        summary[scope]['score'] = ballot_score(scope, skip_cache: true)
        summary[scope]['weighted_ballot_total'] =
          weighted_ballot_total(scope, skip_cache: true)
        summary[scope]['weighted_ballot_score'] =
          weighted_ballot_score(scope, skip_cache: true)
        summary[scope]['weighted_ballot_average'] =
          weighted_ballot_average(scope, skip_cache: true)
      end
    end

    def scoped_cache_summary(scope = nil)
      if scope.nil?
        cached_ballot_summary.fetch(scope) { cached_ballot_summary.fetch('') { {} } }
      else
        cached_ballot_summary[scope] || {}
      end
    end

    def __ballot_votable_kwargs(voter, kwargs)
      if voter.kind_of?(Hash)
        kwargs.merge(voter)
      elsif voter.nil?
        kwargs
      else
        kwargs.merge(voter: voter)
      end
    end

    # Methods added to the Votable model class.
    module ClassMethods
      # The class is now a votable record.
      def ballot_votable?
        true
      end
    end
  end
end
