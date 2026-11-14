function idxActive = returnOrder(order, active)
% Returns indices of active environments sorted by their order (rank).
% order(env) is the rank of env among active environments (1 = first).
if length(order) ~= length(active), error('Failure...'); end
idxActive = find(active);
[~, sortIdx] = sort(order(idxActive));
idxActive = idxActive(sortIdx);
