data = load('training.txt');

y = data(:,2); X = data(:,3:98);

dataval = load('validation.txt');

yval = dataval(:,2); Xval = dataval(:,3:98);


[m, n] = size(X);

[mval, nval] = size(Xval);

X = [ones(m, 1) X];

Xval = [ones(mval, 1) Xval];

theta = load('theta_log.txt');

error=lrCostFunction(theta, X, y,  0);
error_val=lrCostFunction(theta, Xval, yval,  0);

a=mean(double(predict(theta, X)==y))*100;
aval=mean(double(predict(theta, Xval)==yval))*100;