(* ::Package:: *)

BeginPackage["CPUDistances`"]

CGRStats::usage = 
	"CGRStats[img] gives some useful statistics for a CGR image, which may be used to accelerate ApproxInfoDist and PearsonDistance"

Descriptor::usage = 
	"Descriptor[img, winsizes, steps, histbins] gives the descriptor of a matrix, given the windowsizes, windowsteps and histogram bins"
Descriptor::lengtherr = 
	"winsizes and steps must have the same length"

SSIM::usage = 
	"SSIM[img1, img2] gives the structural similarity distance between two images"
SSIMExact::usage = 
	"SSIMExact[img1, img2] gives the structural similarity distance between two images, using a slower method which should be slightly more accurate"

ApproxInfoDist::usage = 
	"ApproxInfoDist[vect1, vect2] gives the approximate information distance between two vectors"

PearsonDistance::usage = 
	"PearsonDistance[vect1, vect2] gives the Pearson correlation coefficient distance between two vectors"


Begin["`Private`"]

CGRStats[img_List?MatrixQ]:=
	Module[{vect, mean},
		vect = Flatten[img];
		mean = Mean[vect];
		
		Return[{
			Total@Unitize[vect], (* for ApproxInfoDist *)
			mean, (* for PearsonDistance *)
			Norm[vect-mean] (* for PearsonDistance *)
		}];
	];

Descriptor[img_List?MatrixQ, winsizes_List, steps_List, histbins_List]:=
	Module[{allwinds, currsize, currstep, winds},
		If[Length[winsizes] != Length[steps],
			Message[Descriptor::lengtherr];
			Return[$Failed];
		];
		
		allwinds = Map[(
			{currsize, currstep} = #;
			
			winds = Partition[img, {currsize, currsize}, currstep];
			
			(* note: Length/@BinLists is ~2x faster than BinCounts here *)
			Flatten@Map[(Length/@BinLists[Flatten[#], {histbins}]) / (currsize^2)&, winds, {2}]
		)&, Transpose[{winsizes, steps}]];
		
		Return[Flatten[allwinds]];
	];

SSIM = Compile[{{img1, _Integer, 2}, {img2, _Integer, 2}},
	Module[{w, c1, c2, m1, m2, m1sq, m2sq, m1m2, sigma1sq, sigma2sq, sigma12, ssimmap},
		(* like w = N[GaussianMatrix[{5, 1.5}], 16] - this is 15-20% faster *)
		w = {{0.000003802917046317888,0.00001759448244809565,0.00006636107686176908,0.0001945573540794799,0.0004122408174475112,0.0005609936362550451,0.0004122408174475112,0.0001945573540794799,0.00006636107686176908,0.00001759448244809565,0.000003802917046317888},
			 {0.00001759448244809565,0.0000814021996393737,0.0003070245256103131,0.000900134267933542,0.001907263224158832,0.002595479356074726,0.001907263224158832,0.000900134267933542,0.0003070245256103131,0.0000814021996393737,0.00001759448244809565},
			 {0.00006636107686176908,0.0003070245256103131,0.001158003834587327,0.003395034751176518,0.007193621170012245,0.00978936468007629,0.007193621170012245,0.003395034751176518,0.001158003834587327,0.0003070245256103131,0.00006636107686176908},
			 {0.0001945573540794799,0.000900134267933542,0.003395034751176518,0.00995356027107092,0.02109025301085816,0.02870045183627817,0.02109025301085816,0.00995356027107092,0.003395034751176518,0.000900134267933542,0.0001945573540794799},
			 {0.0004122408174475112,0.001907263224158832,0.007193621170012245,0.02109025301085816,0.04468740430042675,0.06081239016679303,0.04468740430042675,0.02109025301085816,0.007193621170012245,0.001907263224158832,0.0004122408174475112},
			 {0.0005609936362550451,0.002595479356074726,0.00978936468007629,0.02870045183627817,0.06081239016679303,0.0827559097623164,0.06081239016679303,0.02870045183627817,0.00978936468007629,0.002595479356074726,0.0005609936362550451},
			 {0.0004122408174475112,0.001907263224158832,0.007193621170012245,0.02109025301085816,0.04468740430042675,0.06081239016679303,0.04468740430042675,0.02109025301085816,0.007193621170012245,0.001907263224158832,0.0004122408174475112},
			 {0.0001945573540794799,0.000900134267933542,0.003395034751176518,0.00995356027107092,0.02109025301085816,0.02870045183627817,0.02109025301085816,0.00995356027107092,0.003395034751176518,0.000900134267933542,0.0001945573540794799},
			 {0.00006636107686176908,0.0003070245256103131,0.001158003834587327,0.003395034751176518,0.007193621170012245,0.00978936468007629,0.007193621170012245,0.003395034751176518,0.001158003834587327,0.0003070245256103131,0.00006636107686176908},
			 {0.00001759448244809565,0.0000814021996393737,0.0003070245256103131,0.000900134267933542,0.001907263224158832,0.002595479356074726,0.001907263224158832,0.000900134267933542,0.0003070245256103131,0.0000814021996393737,0.00001759448244809565},
			 {0.000003802917046317888,0.00001759448244809565,0.00006636107686176908,0.0001945573540794799,0.0004122408174475112,0.0005609936362550451,0.0004122408174475112,0.0001945573540794799,0.00006636107686176908,0.00001759448244809565,0.000003802917046317888}};
		c1 = 0.01^2;
		c2 = 0.03^2;
		
		m1 = ListCorrelate[w, img1];
		m2 = ListCorrelate[w, img2];
		
		m1sq = m1^2;
		m2sq = m2^2;
		m1m2 = m1*m2;
		
		sigma1sq = ListCorrelate[w, img1^2] - m1sq;
		sigma2sq = ListCorrelate[w, img2^2] - m2sq;
		sigma12 = ListCorrelate[w, img1*img2] - m1m2;
		
		ssimmap = ((c1 + 2*m1m2)*(c2 + 2*sigma12)) / ((c1 + m1sq + m2sq)*(c2 + sigma1sq + sigma2sq));
		
		Mean[Mean[ssimmap]]
	]
, RuntimeOptions -> "Speed"];

SSIMExact[img1_List?MatrixQ, img2_List?MatrixQ]:=
	Module[{w, c1, c2, m1, m2, m1sq, m2sq, m1m2, sigma1sq, sigma2sq, sigma12, ssimmap},
		w = GaussianMatrix[{5, 1.5}];
		c1 = 0.01^2;
		c2 = 0.03^2;
		
		m1 = ListCorrelate[w, img1];
		m2 = ListCorrelate[w, img2];
		
		m1sq = m1^2;
		m2sq = m2^2;
		m1m2 = m1*m2;
		
		sigma1sq = ListCorrelate[w, img1^2] - m1sq;
		sigma2sq = ListCorrelate[w, img2^2] - m2sq;
		sigma12 = ListCorrelate[w, img1*img2] - m1m2;
		
		ssimmap = ((c1 + 2*m1m2)*(c2 + 2*sigma12)) / ((c1 + m1sq + m2sq)*(c2 + sigma1sq + sigma2sq));
		
		Return[Mean[Mean[ssimmap]]];
	];

(* without CGRStats *)
ApproxInfoDist[vect1_List?VectorQ, vect2_List?VectorQ]:=
	Module[{x, y, xy},
		x = Total@Unitize[vect1]; 
		y = Total@Unitize[vect2];
		xy = Total@Unitize[vect1 + vect2];

		Return[(2 xy - x - y)/xy];
	];

(* with CGRStats *)
ApproxInfoDist[{vect1_List?VectorQ, stats1_}, {vect2_List?VectorQ, stats2_}]:=
	Module[{x, y, xy},
		x = stats1[[1]]; 
		y = stats2[[1]];
		xy = Total@Unitize[vect1 + vect2];

		Return[(2 xy - x - y)/xy];
	];

(* without CGRStats *)
PearsonDistance[vect1_List?VectorQ, vect2_List?VectorQ]:=
	Module[{mean1, mean2, norm1, norm2},
		mean1 = Mean[vect1];
		mean2 = Mean[vect2];
		
		norm1 = Norm[vect1-mean1];
		norm2 = Norm[vect2-mean2];
		
		Return[1 - (vect1-mean1).(vect2-mean2)/(norm1 * norm2)];
	];

(* with CGRStats *)
PearsonDistance[{vect1_List?VectorQ, stats1_}, {vect2_List?VectorQ, stats2_}]:=
	Module[{mean1, mean2, norm1, norm2},
		{mean1, norm1} = stats1[[{2, 3}]];
		{mean2, norm2} = stats2[[{2, 3}]];
		
		Return[1 - (vect1-mean1).(vect2-mean2)/(norm1 * norm2)];
	];


End[]
EndPackage[]
