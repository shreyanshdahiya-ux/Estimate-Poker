import { LightningElement, api, track } from "lwc";

export default class VoteResults extends LightningElement {
  @api votes = [];
  @api statistics = {};
  @api scaleValues = [];
  @api storyTotalTime; // Add this
  @api allMembers = []; // All room members who can vote

  get hasVotes() {
    return this.votes && this.votes.length > 0;
  }

  get hasConsensus() {
    // Needs at least two votes; one vote cannot be a consensus
    return (this.statistics?.hasConsensus || false) && this.votersCount >= 2;
  }

  get hasOutliers() {
    return (this.statistics?.outlierCount || 0) > 0;
  }

  get hasHighVariance() {
    // High variance if range is more than 50% of max value
    if (!this.statistics?.range || !this.statistics?.max) return false;
    return this.statistics.range > this.statistics.max * 0.5;
  }

  get varianceLevel() {
    if (!this.statistics?.range) return "low";
    const range = this.statistics.range;
    if (range <= 2) return "low";
    if (range <= 5) return "medium";
    return "high";
  }

  get varianceMessage() {
    const messages = {
      low: "Low variance - Team is aligned",
      medium: "Medium variance - Some discussion may help",
      high: "High variance - Discussion recommended"
    };
    return messages[this.varianceLevel] || "";
  }

  get formattedStatistics() {
    if (!this.statistics) return {};

    return {
      average: this.formatNumber(this.statistics.average),
      median: this.formatNumber(this.statistics.median),
      min: this.statistics.min || "-",
      max: this.statistics.max || "-",
      range: this.statistics.range || 0,
      standardDeviation: this.formatNumber(this.statistics.standardDeviation)
    };
  }

  formatNumber(num) {
    if (num === null || num === undefined) return "-";
    return Number(num).toFixed(1);
  }

  isOutlier(voteValue) {
    const avg = this.statistics?.average || 0;
    const stdDev = this.statistics?.standardDeviation || 0;
    const numValue = parseFloat(voteValue) || 0;
    return stdDev > 0 && Math.abs(numValue - avg) > 1.5 * stdDev;
  }

  get formattedVotes() {
    const votes = (Array.isArray(this.votes) ? this.votes : []).filter(
      (v) => v.hasVoted !== false
    );
    if (votes.length === 0) return [];

    return votes.map((vote) => {
      // Calculate formatted duration
      let durationDisplay = "--:--";
      if (vote.duration) {
        const mins = Math.floor(vote.duration / 60);
        const secs = vote.duration % 60;
        durationDisplay = `${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
      }

      return {
        ...vote,
        value: vote.value, // Always show value since this component is only shown when revealed
        duration: durationDisplay,
        isOutlier: this.isOutlier(vote.value),
        cardClass: `vote-card ${this.isOutlier(vote.value) ? "outlier" : ""}`,
        hasComment: vote.comment && vote.comment.trim().length > 0
      };
    });
  }

  get distributionData() {
    if (!this.statistics?.distribution) return [];

    const distribution = this.statistics.distribution;
    const votes = (Array.isArray(this.votes) ? this.votes : []).filter(
      (v) => v.hasVoted !== false
    );
    const totalVotes = votes.length;
    const maxCount = Math.max(...Object.values(distribution), 1);

    // Use scale values to maintain order
    const orderedData = [];

    for (const value of this.scaleValues) {
      const count = distribution[value] || 0;
      if (count > 0) {
        const heightPercent = (count / maxCount) * 100;
        const percentage = Math.round((count / totalVotes) * 100);
        orderedData.push({
          value,
          count,
          percentage,
          barStyle: `height: ${heightPercent}%`,
          barClass: count === maxCount ? "chart-bar highest" : "chart-bar"
        });
      }
    }

    // Add any values not in scale (edge case)
    for (const [value, count] of Object.entries(distribution)) {
      if (!orderedData.some((d) => d.value === value)) {
        const heightPercent = (count / maxCount) * 100;
        const percentage = Math.round((count / totalVotes) * 100);
        orderedData.push({
          value,
          count,
          percentage,
          barStyle: `height: ${heightPercent}%`,
          barClass: count === maxCount ? "chart-bar highest" : "chart-bar"
        });
      }
    }

    return orderedData;
  }

  @track viewType = "bar"; // 'bar' or 'pie'

  get isBarView() {
    return this.viewType === "bar";
  }
  get isPieView() {
    return this.viewType === "pie";
  }

  handleViewChange(event) {
    this.viewType = event.currentTarget.dataset.view;
  }

  get pieChartStyle() {
    if (!this.hasDistribution) return "";

    let gradient = "conic-gradient(";
    let startPercent = 0;

    // Colors corresponding to scale values if possible, or reliable palette
    const colors = [
      "#3F51B5",
      "#10B981",
      "#F59E0B",
      "#EF4444",
      "#8B5CF6",
      "#EC4899",
      "#6366F1",
      "#14B8A6"
    ];

    this.distributionData.forEach((data, index) => {
      const endPercent = startPercent + data.percentage;
      const color = colors[index % colors.length];
      gradient += `${color} ${startPercent}% ${endPercent}%, `;
      startPercent = endPercent;
    });

    // Remove trailing comma and space
    gradient = gradient.slice(0, -2);
    gradient += ")";

    return `background: ${gradient}`;
  }

  get firstVoter() {
    if (!this.votes || this.votes.length === 0) return null;
    // Filter out those who haven't voted just in case, though votes usually implies hasVoted=true
    const sorted = [...this.votes]
      .filter((v) => v.hasVoted !== false)
      .sort((a, b) => {
        return new Date(a.votedAt) - new Date(b.votedAt);
      });
    return sorted.length > 0 ? sorted[0] : null;
  }

  get lastVoter() {
    if (!this.votes || this.votes.length === 0) return null;
    const sorted = [...this.votes]
      .filter((v) => v.hasVoted !== false)
      .sort((a, b) => {
        return new Date(b.votedAt) - new Date(a.votedAt);
      });
    return sorted.length > 0 ? sorted[0] : null;
  }

  // Only claim the whole team agrees when everyone who can vote did vote
  get consensusMessage() {
    if (this.hasNonVoters) {
      return `All ${this.votersCount} votes cast agree (${this.nonVoters.length} did not vote)`;
    }
    return "All team members agree";
  }

  get votersCount() {
    const votes = Array.isArray(this.votes) ? this.votes : [];
    return votes.filter((v) => v.hasVoted !== false).length;
  }

  get nonVoters() {
    // Ensure arrays are valid
    const allMembers = Array.isArray(this.allMembers) ? this.allMembers : [];
    if (allMembers.length === 0) return [];

    const votes = Array.isArray(this.votes) ? this.votes : [];

    // Get list of user IDs who voted
    const voterIds = new Set(
      votes.filter((v) => v.hasVoted !== false).map((v) => v.odataUserId)
    );

    // Filter members who can vote but didn't
    return allMembers
      .filter((member) => member.canVote && !voterIds.has(member.odataUserId))
      .map((member) => ({
        ...member,
        displayName: member.voterName || member.userName,
        photoUrl: member.voterPhoto || member.photoUrl
      }));
  }

  get hasNonVoters() {
    return this.nonVoters && this.nonVoters.length > 0;
  }
}
